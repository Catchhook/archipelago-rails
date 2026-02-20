# frozen_string_literal: true

module Archipelago
  class Configuration
    attr_accessor :root_namespace,
                  :current_user_method,
                  :current_user_resolver,
                  :authorize_by_default,
                  :strict_origin_check,
                  :allowed_redirect_hosts,
                  :version_source

    def initialize
      @root_namespace = "Islands"
      @current_user_method = :current_user
      @current_user_resolver = nil
      @authorize_by_default = true
      @strict_origin_check = false
      @allowed_redirect_hosts = []
      @version_source = -> { (Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)).to_i }
    end
  end
end
