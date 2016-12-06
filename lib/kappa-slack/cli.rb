require 'thor'

module KappaSlack
  class CLI < Thor::Group
    class_option :slack_email, default: ENV['SLACK_EMAIL'], required: true, type: :string
    class_option :slack_password, default: ENV['SLACK_PASSWORD'], required: true, type: :string
    class_option :slack_team_name, default: ENV['SLACK_TEAM_NAME'], required: true, type: :string
    class_option :skip_bttv_emotes, type: :boolean, default: false
    class_option :skip_one_letter_emotes, type: :boolean, default: true
    class_option :user, type: :string, default: ''

    def self.banner
      'kappa-slack [options]'
    end

    def upload
      Uploader.new(**options.to_hash.symbolize_keys).upload
    end
  end
end
