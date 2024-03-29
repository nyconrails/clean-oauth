class OAuthUser

  attr_reader :provider, :user

  def initialize creds, user = nil
    @auth         = creds
    @user         = user
    @provider     = @auth.provider
    @is_logged_in = user ? true : false
    @policy       = "#{@provider}_policy".classify.constantize.new(@auth)
  end

  def login_or_create
    logged_in? ? create_new_account : (login || create_new_account)
  end

  def logged_in?
    @is_logged_in
  end


  private

    def login
      @account = Account.where(@auth.slice("provider", "uid")).first
      if @account.present?
        refresh_tokens
        @user = @account.user
        @policy.refresh_callback(@account)
      else
        false
      end
    end

    def create_new_account
      create_new_user if @user.nil?

      @account = @user.accounts.create!(
        :provider      => @provider,
        :uid           => @policy.uid,
        :oauth_token   => @policy.oauth_token,
        :oauth_expires => @policy.oauth_expires,
        :username      => @policy.username
      )

      @policy.create_callback(@account)
    end

    def create_new_user
      @user = User.create!(
        :first_name => @policy.first_name,
        :last_name  => @policy.last_name,
        :email      => @policy.email,
        :picture    => image
      )
    end

    def image
      image = open(URI.parse(@policy.image_url), :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE)
      def image.original_filename; base_uri.path.split('/').last; end
      image
    end

    def refresh_tokens
      @account.update_attributes(
        :oauth_token   => @policy.oauth_token,
        :oauth_expires => @policy.oauth_expires
      )
    end

end