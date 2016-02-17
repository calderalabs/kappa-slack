require 'mechanize'
require 'httpclient'
require 'httpclient/webagent-cookie'
require 'json'
require 'fileutils'
require 'digest/sha1'

module KappaSlack
  class Uploader
    def initialize(slack_team_name:, slack_email:, slack_password:)
      @slack_team_name = slack_team_name
      @slack_email = slack_email
      @slack_password = slack_password
    end

    def browser
      @browser ||= Mechanize.new
    end

    def http
      @http ||= HTTPClient.new
    end

    def visit(path, &block)
      browser.get(URI.join("https://#{slack_team_name}.slack.com", path), &block)
    end

    def bttv_emotes
      response = JSON.parse(http.get_content('https://api.betterttv.net/2/emotes'))
      url_template = "https:#{response['urlTemplate'].gsub('{{image}}', '1x')}"

      response['emotes'].map do |emote|
        {
          name: emote['code'].parameterize,
          url: url_template.gsub('{{id}}', emote['id'])
        }
      end
    end

    def twitch_emotes
      response = JSON.parse(http.get_content('https://twitchemotes.com/api_cache/v2/global.json'))
      url_template = response['template']['small']

      response['emotes'].map do |name, emote|
        {
          name: name.parameterize,
          url: url_template.gsub('{image_id}', emote['image_id'].to_s)
        }
      end
    end

    def emotes
      bttv_emotes + twitch_emotes
    end

    def upload
      visit('/') do |login_page|
        login_page.form_with(:id => 'signin_form') do |form|
          form.email = slack_email
          form.password = slack_password
        end.submit

        KappaSlack.logger.info "Logged in as #{slack_email}"

        visit('/admin/emoji') do |emoji_page|
          uploaded_page = emoji_page
          tmp_dir_path = "#{APP_ROOT}/tmp"
          FileUtils.mkdir_p(tmp_dir_path)

          emotes.each do |emote|
            existing_emote = uploaded_page.search(".emoji_row:contains(':#{emote[:name]}:')")
            next if existing_emote.present?

            KappaSlack.logger.info "Uploading #{emote[:name]}"
            file_name = "#{tmp_dir_path}/#{Digest::SHA1.hexdigest(emote[:name])}"

            File.open(file_name, 'w') do |file|
              http.get_content(emote[:url]) do |chunk|
                file.write(chunk)
              end
            end

            uploaded_page = uploaded_page.form_with(:id => 'addemoji') do |form|
              form.field_with(:name => 'name').value = emote[:name]
              form.file_upload_with(:name => 'img').file_name = file_name
            end.submit
          end

          FileUtils.rm_rf(tmp_dir_path)
        end
      end
    end

    private

    attr_reader :slack_team_name, :slack_email, :slack_password
  end
end
