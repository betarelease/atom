class Api::V1::RegistrationsController < Api::V1::BaseController
  respond_to :json

  def send_to_mailchimp(mc_params)
    mailchimp_professional = '7fcfc645b6a8c6329e0ff0a1ad9551ab1be41775'
    mailchimp_news = '4d672d5dac3875fd715e0ea59e7d5b51bd82fc98'
    mailchimp_payers = '78c50d3dece0c6296f56eef01a4273dfd73c508d'

    news_list_id = 'a0d4e53ea9'
    professional_list_id = 'fc079c1742'
    payers_list_id = '45b8a4f230'
    if mc_params[:mailbox] == mailchimp_news
      list = news_list_id
    elsif mc_params[:mailbox] == mailchimp_professional
      list = professional_list_id
    elsif mc_params[:mailbox] == mailchimp_payers
      list = payers_list_id
    else
      list = ''
    end

    first_name = mc_params[:first_name] || ''
    last_name = mc_params[:last_name] || ''
    merge_vars = {FNAME: first_name, LNAME: last_name}
    params = {id: list, email_address: mc_params[:email], merge_vars: merge_vars, double_optin: false, update_existing: true}
    Feralchimp.new(api_key: ENV['mailchimp_api_key']).list_subscribe(params)
  end

  def create
    if User.find_by(email: params[:user][:email])
      render json: {success: false, error: 'The email address belongs to an existing account. '\
                                           'Please sign up with a different email address.'}, status: 422
      return
    end

    user = User.new(params[:user])
    user.modification_date = Time.now
    user.updated_by = 'server'
    user.first_name = params[:user][:first_name]
    user.last_name = params[:user][:last_name]
    user.sort_value = "#{user.last_name}#{user.first_name}".downcase
    user.news_letter = params[:user][:news_letter]
    user.roles = ['patient']
    user.guid = UUIDTools::UUID.timestamp_create.to_s

    code = user.generate_glooko_code
    until User.where(glooko_code: code).count == 0
      code = user.generate_glooko_code
    end

    user.glooko_code = code
    if params[:product][:name] == 'kiosk'
      user.temp_token = Digest::MD5.hexdigest(user.guid)
    end

    if user.save
      user.preference = Preference.new
      user.preference.guid = UUIDTools::UUID.timestamp_create.to_s
      user.preference.modification_date = Time.now
      user.preference.updated_by = 'server'
      user.preference.save!

      send_welcome_email user

      # send scheduled transactional emails
      my_glooko_html = render_to_string(template: 'transactional_emails/web_dashboard', layout: false, formats: :html)
      share_report_html = render_to_string(template: 'transactional_emails/share_report', layout: false, formats: :html)
      sync_multiple_meters_html = render_to_string(template: 'transactional_emails/sync_meters', layout: false, formats: :html)
      TransactionalEmailsWorker.add_new_worker(user.glooko_code, my_glooko_html, share_report_html, sync_multiple_meters_html)

      if user.news_letter
        mailchimp_params = {
            mailbox: '4d672d5dac3875fd715e0ea59e7d5b51bd82fc98',
            email: user.email,
            first_name: user.first_name,
            last_name: user.last_name
        }
        send_to_mailchimp mailchimp_params
      end

      render json: {success: true}, status: 201
    else
      warden.custom_failure!
      render json: {success: false, error: 'Your username or password appears to be invalid. Please enter a valid '\
                                           'email and password. Hint: your password should be at least 7 characters '\
                                           'long and contain at least one number.'}, status: 422
    end
  end

  def send_welcome_email(user)
    product = params[:product]
    app_version = Gem::Version.new(product[:app_release])
    if product[:name] == 'kiosk' && (product[:os]== 'android' || app_version >= Gem::Version.new('1.3'))
      UserGlookoPasswordMailer.welcome(user).deliver
    else
      UserMailer.welcome(user).deliver_now
    end
  end

end
