require 'mechanize'
require 'httpclient'
require 'httpclient/webagent-cookie'
require 'json'
require 'fileutils'
require 'digest/sha1'

module KappaSlack
  class Uploader
    def initialize(
      slack_team_name:,
      slack_email:,
      slack_password:,
      skip_bttv_emotes:,
      user:,
      skip_one_letter_emotes:)
      @slack_team_name = slack_team_name
      @slack_email = slack_email
      @slack_password = slack_password
      @skip_bttv_emotes = skip_bttv_emotes
      @user = user
      @skip_one_letter_emotes = skip_one_letter_emotes
    end

    def upload
      visit('/') do |login_page|
        login_page.form_with(:id => 'signin_form') do |form|
          form.email = slack_email
          form.password = slack_password
        end.submit

        visit('/admin/emoji') do |emoji_page|
          uploaded_page = emoji_page
          tmp_dir_path = File.join(APP_ROOT, 'tmp')
          FileUtils.mkdir_p(tmp_dir_path)

          emotes.each do |emote|
            existing_emote = uploaded_page.search(".emoji_row:contains(':#{emote[:name]}:')")
            next if existing_emote.present?
            file_path = File.join(tmp_dir_path, Digest::SHA1.hexdigest(emote[:name]))

            File.open(file_path, 'w') do |file|
              http.get_content(emote[:url]) do |chunk|
                file.write(chunk)
              end
            end

            next if File.size(file_path) > 64 * 1024
            KappaSlack.logger.info "Uploading #{emote[:name]}"

            uploaded_page = uploaded_page.form_with(:id => 'addemoji') do |form|
              form.field_with(:name => 'name').value = emote[:name]
              form.file_upload_with(:name => 'img').file_name = file_path
            end.submit
          end

          FileUtils.rm_rf(tmp_dir_path)
        end
      end
    end

    private

    attr_reader :slack_team_name, :slack_email, :slack_password

    def skip_bttv_emotes?
      @skip_bttv_emotes
    end

    def skip_one_letter_emotes?
      @skip_one_letter_emotes
    end

    def user
      @user
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
      response = JSON.parse(http.get_content('https://twitchemotes.com/api_cache/v3/global.json'))
      url_template = 'https://static-cdn.jtvnw.net/emoticons/v1/{id}/1.0'

      response.map do |name, emote|
        {
          name: name.parameterize,
          url: url_template.gsub('{id}', emote['id'].to_s)
        }
      end
    end

    def twitch_sub(user)
      response = JSON.parse(http.get_content('https://twitchemotes.com/api_cache/v2/subscriber.json'))
      url_template = response['template']['small']

      response['channels'][user]['emotes'].map do |emote|
        {
          name: emote['code'].parameterize,
          url: url_template.gsub('{image_id}', emote['image_id'].to_s)
        }
      end
    end

    def emotes
      all_emotes = twitch_emotes
      all_emotes += bttv_emotes unless skip_bttv_emotes?
      all_emotes += twitch_sub(user) unless user.eql? ""

      if skip_one_letter_emotes?
        all_emotes.select { |e| e[:name].length > 1 }
      else
        all_emotes
      end
    end
  end
end
