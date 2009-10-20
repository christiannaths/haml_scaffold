class InlineFormErrors < ActionView::Helpers::FormBuilder
  #Adds error message directly inline to a form label
  #Accepts all the options normall passed to form.label as well as:
  #  :hide_errors - true if you don't want errors displayed on this label
  #  :append_text - Will add additional text after the error message or after the label if no errors
  def label(method, text = nil, options = {})
    #Check to see if text for this label has been supplied and humanize the field name if not.
    text ||= method.to_s.humanize
    #Get a reference to the model object
    
    object = @template.instance_variable_get("@#{@object_name}")#.split('[').first#.gsub('[', '').gsub(']', '').gsub('_attributes', '')

    #Add any additional text that might be needed before the label
    text = " #{options[:prepend_text]}" + text if options[:prepend_text]

    #Make sure we have an object and we're not told to hide errors for this label
    unless object.nil? || options[:hide_errors]
      #Check if there are any errors for this field in the model
      errors = object.errors.on(method.to_sym)
      if errors
        #Generate the label using the text as well as the error message wrapped in a span with error class
        text += " <span class=\"error_message\">#{errors.is_a?(Array) ? errors.first : errors}</span>"
        options.merge!(:class => "invalid")
      end
    end
    
    #Add any additional text that might be needed after the label
    text += " #{options[:append_text]}" if options[:append_text]
    
    #Finally hand off to super to deal with the display of the label
    super(method, text, options)
  end
end