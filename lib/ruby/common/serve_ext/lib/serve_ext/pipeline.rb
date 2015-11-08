module Serve
  class Pipeline
    def find_layout_for(template_path)
      return Template::Passthrough.new(@template) unless @template.layout?

      root = @root_path
      layout = nil
      search = File.split(template_path[root.size..-1])

      [
        File.join( template_path, "all.layout"),
        File.join( template_path, @template.file[0...(-1*File.extname(@template.file).size)] + ".layout"),
      ].each do |layout_file|
        if File.file?(layout_file)
          layout_path = File.new(layout_file).gets.strip
          layout = layout_path if File.file?(layout_path)
        end
      end

      until(layout || search.empty?)
        possible_layouts = FileTypeHandler.extensions.map do |ext|
          l = "_layout.#{ext}"
          possible_layout = File.join(File.join(root, *search), l)
          File.file?(possible_layout) ? possible_layout : false
        end
        layout = possible_layouts.detect { |o| o }
        search.pop
      end

      if layout
        Template.new(layout)
      else
        Template::Passthrough.new(@template)
      end
    end
  end
end

