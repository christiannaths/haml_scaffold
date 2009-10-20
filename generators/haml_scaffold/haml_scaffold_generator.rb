class HamlScaffoldGenerator < Rails::Generator::NamedBase
  default_options :skip_timestamps => false, :skip_migration => false, :layout => false, :erb => false

  attr_reader   :controller_name, :controller_class_path, :controller_file_path, :controller_class_nesting, :controller_class_nesting_depth, :controller_class_name, :controller_underscore_name, :controller_singular_name, :controller_plural_name, :app_name
  alias_method  :controller_file_name,  :controller_underscore_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super
    @app_name = Rails.root.to_s.split('/').last.capitalize.inspect
    @controller_name = @name.pluralize
    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_underscore_name, @controller_plural_name = inflect_names(base_name)
    @controller_singular_name=base_name.singularize
    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
  end

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, test and stylesheets directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('app/helpers', controller_class_path))
      m.directory(File.join('app/views', controller_class_path, controller_file_name))
      m.directory(File.join('app/views/layouts', controller_class_path))
      m.directory(File.join('test/functional', controller_class_path))
      m.directory(File.join('test/unit', class_path))
      m.directory(File.join('public/stylesheets', class_path))
      m.directory(File.join('public/stylesheets/sass', class_path)) unless options[:erb]

      #views
      scaffold_views.each { |action| m.template( "#{ extension.first }/#{ action }.html.#{ extension.first }", File.join('app/views', controller_class_path, controller_file_name, "#{ action }.html.#{ extension.first }")) }
      m.template( "#{ extension.first }/_form.html.#{ extension.first }", File.join('app/views', controller_class_path, controller_file_name, "_form.html.#{ extension.first }"))
      m.template( "#{ extension.first }/_record.html.#{ extension.first }", File.join('app/views', controller_class_path, controller_file_name, "_#{ controller_file_name.singularize }.html.#{ extension.first }"))



      # Layouts, stylesheets, javascripts
      if options[:layout]
        # layout files
        m.template("#{ extension.first }/layout.html.#{ extension.first }", File.join("app/views/layouts", controller_class_path, "application.html.#{ extension.first }"))
        m.file("#{ extension.first }/_includes.html.#{ extension.first }", "app/views/layouts/_includes.html.#{ extension.first }")
        m.file("#{ extension.first }/_flashes.html.#{ extension.first }", "app/views/layouts/_flashes.html.#{ extension.first }")
        # sytle sheet
        m.file("#{ extension.last }/application.#{ extension.last }", "public/stylesheets/sass/application.#{ extension.last }")
        
        # blueprint css
        m.directory(File.join("public/stylesheets/blueprint", class_path))
        m.file("css/blueprint/ie.css", "public/stylesheets/blueprint/ie.css")
        m.file("css/blueprint/print.css", "public/stylesheets/blueprint/print.css")
        m.file("css/blueprint/screen.css", "public/stylesheets/blueprint/blueprint.css")
          
        #jquery-ui (4 default themes)
        for ui_theme in ui_themes do
          images = Dir.glob(base_dir + templates_dir + "css/jquery-ui/#{ ui_theme }/images/*.png")
          m.directory(File.join("public/stylesheets/jquery-ui/#{ ui_theme }/images", class_path))
          m.file("css/jquery-ui/#{ ui_theme }/jquery-ui-1.7.2.custom.css", "public/stylesheets/jquery-ui/#{ ui_theme }/jquery-ui-1.7.2.custom.css", :collision => :skip)
          for image in images do
            image = image.split("/").last
            m.file("css/jquery-ui/#{ ui_theme }/images/#{ image }", "public/stylesheets/jquery-ui/#{ ui_theme }/images/#{ image }", :collision => :skip)
          end
        end
        
        #javascript
        m.directory(File.join("public/javascripts/", class_path))
        m.file("js/jquery-1.3.2.min.js", "public/javascripts/jquery-1.3.2.min.js")
        m.file("js/jquery-ui-1.7.2.custom.min.js", "public/javascripts/jquery-ui-1.7.2.custom.min.js")
        m.file("js/application.js", "public/javascripts/application.js")
      end
      
      # stylesheet for each resource
      m.template("css/resource.css", "public/stylesheets/#{ controller_file_name }.css") if options[:erb]
      m.template("sass/resource.sass", "public/stylesheets/sass/#{ controller_file_name }.#{ extension.last }") unless options[:erb]
      m.add_stylesheet_link controller_file_name, (base_dir + "app/views/layouts/_includes.html.#{ extension.first }")
      

      # controller, helper, and tests
      m.template("controller.rb", File.join("app/controllers", controller_class_path, "#{ controller_file_name }_controller.rb") )
      m.template("functional_test.rb", File.join("test/functional", controller_class_path, "#{ controller_file_name }_controller_test.rb"))
      m.template("helper.rb",          File.join("app/helpers",     controller_class_path, "#{ controller_file_name }_helper.rb"))

      # restful routes
      m.route_resources controller_file_name

      m.dependency 'model', [name] + @args, :collision => :skip
    end
  end

  protected

    def banner
      "Usage: #{$0} #{ extension.first }_scaffold ModelName [field:type, field:type]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-timestamps", "Don't add timestamps to the migration file for this model") { |v| options[:skip_timestamps] = v }
      opt.on("--skip-migration", "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
      opt.on("--layout", "Generate the layout files") { |v| options[:layout] = v }
      opt.on("--erb", "Generate using ERB templates") { |v| options[:erb] = v }
    end

    def scaffold_views
      %w[ index show new edit ]
    end

    def model_name
      class_name.demodulize
    end
    
    def ui_themes
      %w[ black-tie cupertino smoothness vader ]
    end
    
    def base_dir
      Dir.getwd.to_s + "/"
    end
    
    def templates_dir
      "vendor/plugins/haml_scaffold/generators/haml_scaffold/templates/"
    end
    
    def add_stylesheet_link(link, path, cache=[], last_occurrence=0)
      File.open(path, 'r') { |original| original.each { |line| cache << line } }
      for line in cache do
        last_occurrence = cache.index(line) if line.match(/stylesheet_link_tag/)
      end
      cache.insert(last_occurrence + 1, "\n= stylesheet_link_tag '#{ link }'\n") unless options[:erb]
      cache.insert(last_occurrence + 1, "\n<%= stylesheet_link_tag '#{ link }' %>\n") if options[:erb]
      File.open(path, 'w') { |changed| changed.puts(cache) }
    end
    
    def extension(opt = options[:erb], extension=[])
      extension = case 
        when opt then ["erb", "css"]
        else ["haml", "sass"]
      end
      return extension
    end
end
