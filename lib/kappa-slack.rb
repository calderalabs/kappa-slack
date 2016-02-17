require 'active_support'
require 'active_support/core_ext'

module KappaSlack
  autoload :CLI, 'kappa-slack/cli'
  autoload :Uploader, 'kappa-slack/uploader'

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end
