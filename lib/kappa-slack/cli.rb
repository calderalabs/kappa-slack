require 'thor'

module KappaSlack
  class CLI < Thor::Group
    class_option :slack_email, default: ENV['SLACK_EMAIL'], type: :string
    class_option :slack_password, default: ENV['SLACK_PASSWORD'], type: :string
    class_option :slack_team_name, default: ENV['SLACK_TEAM_NAME'], type: :string
    class_option :skip_bttv_emotes, required: false, type: :boolean, default: false
    class_option :skip_one_letter_emotes, required: false, type: :boolean, default: true

    def self.banner
      'kappa-slack [options]'
    end

    def upload
      Uploader.new(**options.to_hash.symbolize_keys).upload
    end
  end
end
