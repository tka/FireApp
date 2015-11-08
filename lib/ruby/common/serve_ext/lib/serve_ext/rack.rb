# add 404 handler
module Serve
  class RackAdapter

    # Initialize a Rack endpoint for Serve with the root path to
    # the views directory.
    def initialize(root, is_404_handler = false)
      @root = root
      @is_404_handler = is_404_handler
    end

    # Called by Rack to process a request.
    def call(env)
      request = Request.new(env)

      request.path_info='/404' if @is_404_handler

      response = Response.new()
      process(request, response).to_a
    end
  end
end
