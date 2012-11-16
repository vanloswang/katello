#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.


class Organization < ActiveRecord::Base
  include Glue::Candlepin::Owner if AppConfig.use_cp
  include Glue if AppConfig.use_cp

  include Authorization::Organization
  include Glue::ElasticSearch::Organization if AppConfig.use_elasticsearch

  has_many :activation_keys, :dependent => :destroy
  has_many :providers, :dependent => :destroy
  has_many :products, :through => :providers
  has_many :environments, :class_name => "KTEnvironment", :conditions => {:library => false}, :dependent => :destroy, :inverse_of => :organization
  has_one :library, :class_name =>"KTEnvironment", :conditions => {:library => true}, :dependent => :destroy
  has_many :filters, :dependent => :destroy, :inverse_of => :organization
  has_many :gpg_keys, :dependent => :destroy, :inverse_of => :organization
  has_many :permissions, :dependent => :destroy, :inverse_of => :organization
  has_many :sync_plans, :dependent => :destroy, :inverse_of => :organization
  has_many :system_groups, :dependent => :destroy, :inverse_of => :organization
  serialize :system_info_keys, Array

  attr_accessor :statistics

  default_scope  where(:task_id=>nil) #ignore organizations that are being deleted

  before_create :create_library
  before_create :create_redhat_provider
  validates :name, :uniqueness => true, :presence => true, :katello_name_format => true
  validates :label, :uniqueness => true, :presence => true, :katello_label_format => true
  validates :description, :katello_description_format => true

  before_save { |o| o.system_info_keys = Array.new unless o.system_info_keys }

  if AppConfig.use_cp
    before_validation :create_label, :on => :create
    validate :unique_label

    def create_label
      self.label = self.name.tr(' ', '_') if self.label.blank? && self.name.present?
    end

    def unique_label
      # org is being deleted
      if Organization.find_by_label(self.label).nil? && Organization.unscoped.find_by_label(self.label)
        errors.add(:organization, _(" '%s' already exists and either has been scheduled for deletion or failed deletion.") % self.label)
      end
    end
  end

  def systems
    System.where(:environment_id => environments)
  end

  def promotion_paths
    #I'm sure there's a better way to do this
    self.environments.joins(:priors).where("prior_id = #{self.library.id}").collect do |env|
      env.path
    end
  end

  def redhat_provider
    self.providers.redhat.first
  end

  def create_library
    self.library = KTEnvironment.new(:name => "Library",:label => "Library",  :library => true, :organization => self)
  end

  def create_redhat_provider
    self.providers << ::Provider.new(:name => "Red Hat", :provider_type=> ::Provider::REDHAT, :organization => self)
  end

  def validate_destroy current_org
    def_error = _("Could not delete organization '%s'.")  % [self.name]
    if (current_org == self)
      [def_error, _("The current organization cannot be deleted. Please switch to a different organization before deleting.")]
    elsif (Organization.count == 1)
      [def_error, _("At least one organization must exist.")]
    end
  end

end