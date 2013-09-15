# encoding: utf-8
class Gw::WebmailSetting < ActiveRecord::Base
  include Sys::Model::Base
  include Sys::Model::Auth::Free
  
  class Category
    
    attr_accessor :name
    attr_accessor :title
    attr_reader :configs
    
    def initialize(name, title)
      @name = name.to_s
      @title = title
      @configs = []
    end    
  end
  
  validates_presence_of :user_id, :name
  
  @@config_categories = [
    ['メール一覧', :mail_list],
    ['メール読み取り', :mail_detail] ,
    ['メール送信', :mail_form] ,
    [Application.menu(:sys_address_menu), :sys_address],
    [Application.menu(:address_group_menu), :address],
    ['携帯端末', :mobile]  
  ]

  @@config_categorizing = {
    :mail_list => [:mails_per_page, :mail_list_subject, :mail_list_from_address],
    :mail_detail => [:html_mail_view],
    :mail_form => [:mail_from, :mail_form_size, :sign_position],
    :sys_address => [:sys_address_order],
    :address => [:address_order],
    :mobile => [:mobile_access, :mobile_password]
  }
  
  @@config_names = {
    :mails_per_page => 'メール表示件数',
    :mail_list_subject => '件名',
    :mail_list_from_address => '差出人のメールアドレス',
    :html_mail_view => 'HTMLメールの表示',
    :mail_open_window => 'メールを開くウィンドウ',
    :mail_from => 'メール送信者名',
    :mail_form_size => 'ウィンドウサイズ',
    :sign_position => '署名の位置（返信・転送時）',
    :sys_address_order => '並び順',
    :address_order => '並び順',
    :mobile_access => 'モバイルアクセス',
    :mobile_password => 'モバイルパスワード'
  }
  
  @@config_input_types = {
    :mails_per_page => :select,
    :mail_list_subject => :select,
    :mail_list_from_address => :select,
    :html_mail_view => :select,
    :mail_open_window => :select,
    :mail_from => :select,
    :mail_form_size => :select,
    :sign_position => :select,
    :sys_address_order => :select,
    :address_order => :select,
    :mobile_access => :select,
    :mobile_password => :password_field
  }
  
  @@config_options = {
    :mails_per_page => [['20件（標準）',''],['30件','30'],['40件','40'],['50件','50']],
    :mail_list_subject => [['１行で表示（標準）', ''], ['折り返して表示', 'wrap']],
    :mail_list_from_address => [['表示する（標準）', ''], ['表示しない', 'omit_address']],
    :html_mail_view => [['HTML形式で表示（標準）', ''], ['テキスト形式で表示', 'text']],
    :mail_open_window => [['同じウィンドウ（標準）', ''], ['別のウィンドウ', 'new_window']],
    :mail_from => [['氏名（標準）',''],['メールアドレスのみ','only_address']],
    :mail_form_size => [['小','small'],['中（標準）',''],['大','large']],
    :sign_position => [['引用文の前（標準）', ''], ['引用文の後', 'bottom']],
    :sys_address_order => [['メールアドレス（標準）', ''], ['フリガナ', 'kana'], ['名前', 'name']],
    :address_order => [['メールアドレス（標準）', ''], ['フリガナ', 'kana'], ['並び順指定', 'sort_no']],
    :mobile_access => [['不許可（標準）', '0'], ['許可', '1']]
  }
  
  @@config_messages = {
    :mobile_access => '<div style="color:red;">※パケット定額サービスに入っていない場合、高額の通信料が発生する場合があります。<br />' +
      '「許可」設定を行う場合は、この点をご理解のうえ、ご自身の責任で設定を行ってください。</div>'
  }
  
  def self.user_config_categories
    categories = []
    @@config_categories.each do |name, title|
      categories << Category.new(name, title)
    end
    categories
  end

  def self.user_categorized_configs
    #load configs and save to hash
    tmp = {}
    cond = {:user_id => Core.user.id }
    find(:all, :conditions => cond).each do |conf|
      tmp[conf.name.intern] = conf
    end
    #categorize
    categories = []
    @@config_categories.each do |title, name|
      cat = Category.new(name, title)
      @@config_categorizing[name].each do |conf_name|
        conf = tmp[conf_name] || self.new(cond.merge(:name => conf_name.to_s, :value => ''))
        cat.configs << conf
      end
      categories << cat
    end
    categories
  end
  
  def self.user_configs
    configs = []
    @@config_names.each do |name, title|
      cond = {:user_id => Core.user.id, :name => name}
      conf = find(:first, :conditions => cond) || new(cond)
      configs << conf
    end
    configs
  end
  
  def self.user_config(name)
    cond = {:user_id => Core.user.id, :name => name}
    conf = find(:first, :conditions => cond) || new(cond.merge(:value => ''))
  end
      
  def self.user_config_value(name, nullif = nil)
    if config = user_config(name)
      return config.value unless config.value.blank?
    end
    nullif
  end
  
  def self.user_config_values(names)
    cond = ["user_id = ? and name in (?) ", Core.user.id, names]
    find(:all, :conditions => cond).inject(HashWithIndifferentAccess.new) do |hash, conf|
      hash[conf.name] = conf.value
      hash
    end
  end

  def config_name
    @@config_names[self.name.intern]
  end
  
  def options
    @@config_options[self.name.intern]
  end
  
  def input_type
    @@config_input_types[self.name.intern]
  end
  
  def message
    @@config_messages[self.name.intern]
  end
  
  def value_name
    case input_type
    when :select
      options.each {|name, val| return name if value.to_s == val.to_s } if options
    when :text_field
      return value.blank? ? nil : value
    when :password_field
      return value.blank? ? nil : value.gsub(/./,"*")
    end
    value.blank? ? nil : value
  end
  
  def readable
    self.and :user_id, Core.user.id
    self
  end
  
  def editable?
    return true if Core.user.has_auth?(:manager)
    user_id == Core.user.id
  end
  
  def deletable?
    return true if Core.user.has_auth?(:manager)
    user_id == Core.user.id
  end
  
  def save(*args)
    case name.intern
    when :mobile_access, :mobile_password
      return Gw::WebmailSetting.save_mobile_setting_for_user(Core.user, self)
    end
    super(*args)
  end
  
  def initialize(attributes = nil)
    super(attributes)
    if self.name
      case self.name.intern
      when :mobile_access
        self.value = Core.user.mobile_access.to_s
      when :mobile_password
        self.value = Core.user.mobile_password
      end
    end
    self
  end
  
  def self.save_mobile_setting_for_user(user, item)
    return false unless user
    user[item.name.intern] = item.value
    ret = user.save
    item.errors.merge!(user.errors) unless ret
    ret
  end
end
