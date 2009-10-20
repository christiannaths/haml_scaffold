path = Dir.getwd.to_s + "/" + "config/environment.rb"
File.open(path, 'a') { |file| file.puts "\nActionView::Base.default_form_builder = InlineFormErrors" }
puts "Added default form builder to environment.rb"