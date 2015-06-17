class ProviderGroupSite
  include Mongoid::Document
  include Mongoid::Timestamps

  validates_presence_of :auth_code
  validates_presence_of :name
  validates_presence_of :token_auth_key

  after_save :update_users

  index({token_auth_key: 1}, {unique: true})

  belongs_to :provider_group, index: true
  has_many :users, :inverse_of => 'authorized_viewers'
  has_many :professionals, :class_name => 'User', :inverse_of => 'provider_group_site'
  attr_accessible :_id

  embeds_one :custom_flags, :class_name => CustomFlags.to_s, :inverse_of => 'provider_group_site'
  accepts_nested_attributes_for :custom_flags

  field :name, type: String
  field :auth_code, type: String
  field :contact, type: String
  field :token_auth_key, type: String
  field :hypo_enabled, type: Boolean, default: false
  field :validic_enabled, type: Boolean, default: false

  rails_admin do
    list do
      field :name
      field :provider_group
      field :auth_code
      field :hypo_enabled
      field :validic_enabled
    end
    edit do
      configure :token_auth_key do
        help 'Required. New value is generated for each record.'
      end
    end
  end

  def initialize
    super
    self.token_auth_key = UUIDTools::UUID.timestamp_create.to_s
  end

  def update_users
    if hypo_enabled_changed?
      users.each do |user|
        user.modification_date = Time.now.utc
        user.updated_by = 'server'
        user.save!
      end
    end

    if validic_enabled_changed? && !validic_enabled
      glooko_codes = users.map(&:glooko_code)
      ValidicWorker.add_new_worker(ValidicWorker::VALIDIC_DISCONNECT, glooko_codes)
    end
  end
end