require "ostruct"

module ActiveRecordExtensions
  module ClassMethods
    # Encapsulates pattern for delegating to and validating `belongs_to`
    # associations so that you can write
    #
    #     class Comment < ActiveRecord::Base
    #       strictly_belongs_to :post, :delegating => [ :subdomain ]
    #     end
    #
    # instead of
    #
    #     class Comment < ActiveRecord::Base
    #       belongs_to :post
    #       validates_presence_of :post_id
    #       delegate :subdomain, :to => :post
    #     end
    #
    # Generates proper validation for polymorphic models, passes through
    # `:message, :on, :if, :unless` options to `validates_presence_of`.
    def strictly_belongs_to(table_name, options = {})
      table_name = table_name.to_s
      table_name_sym = table_name.to_sym
      table_foreign_key_sym = options[:foreign_key] || table_name.foreign_key.to_sym

      validates_presence_of_keys = [ :message, :on, :if, :unless ]
      delegate_keys = [ :delegating ]

      # extract delegating options
      delegate_options = options.slice(*delegate_keys)

      # extract validates_presence_of options
      validates_presence_of_options = options.slice(*validates_presence_of_keys)

      # pass any other option to belongs_to
      belongs_to_options = options.except(*(validates_presence_of_keys + delegate_keys))

      belongs_to table_name_sym, belongs_to_options

      if options[:polymorphic]
        validates_presence_of table_foreign_key_sym,
                              table_foreign_key_sym.to_s.sub(/_id$/, "_type").to_sym, 
                              validates_presence_of_options
      else
        validates_presence_of table_foreign_key_sym,
                              validates_presence_of_options
      end

      if delegate_args = delegate_options[:delegating]
        delegate_args = delegate_args.is_a?(Array) ? delegate_args : [ delegate_args ] 
        opts = delegate_args.extract_options!
        opts[:to] = table_name
        delegate *(delegate_args << opts)
      end
    end

    # Quotes passed columns prepending properly quoted table name 
    # (useful for joins of other cases where columns must be fully qualified).
    def my_quote_columns(*column_names)
      quoted_table_name = connection.quote_table_name(self.table_name)
      column_names.map { |column_name| "#{ quoted_table_name }.#{ connection.quote_column_name(column_name) }" }.join(", ")
    end

    # Validates that the attribute is the proper URL.
    def validates_url_format_of(*attr_names)
      configuration = attr_names.extract_options!
      validates_each(attr_names, configuration) do |record, attr_name, value|
        next if value.blank?
        begin
          uri = URI.parse(value)
          unless uri.class == URI::HTTP or uri.class == URI::HTTPS
            record.errors.add(attr_name, "Only HTTP(S) protocol addresses can be used")
          end
        rescue URI::InvalidURIError
          record.errors.add(attr_name, "The format of the url is not valid.")
        end
      end
    end

    # Stolen from restful_authentication
    EMAIL_NAME_REGEX  = '[\w\.%\+\-]+'.freeze
    DOMAIN_HEAD_REGEX = '(?:[A-Z0-9\-]+\.)+'.freeze
    DOMAIN_TLD_REGEX  = '(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum)'.freeze
    EMAIL_REGEX       = /\A#{EMAIL_NAME_REGEX}@#{DOMAIN_HEAD_REGEX}#{DOMAIN_TLD_REGEX}\z/i
    BAD_EMAIL_MESSAGE = "should look like an email address.".freeze

    # Validates that the attribute is a proper email.
    def validates_email_format_of(*attr_names)
      configuration = { :with => EMAIL_REGEX, :message => BAD_EMAIL_MESSAGE }
      configuration.update(attr_names.extract_options!)
      validates_format_of attr_names, configuration
    end

    SUBDOMAIN_REGEX = /\A[A-Za-z0-9][A-Za-z0-9-]*\z/

    # Validates that the attribute can be used as the name of the subdomain.
    def validates_subdomain_format_of(attr_name, options = {})
      validates_format_of attr_name, { :with => SUBDOMAIN_REGEX }.merge(options)
    end

    # Returns random record.
    # The implementation isn't RDBMS vendor specific. 
    def random
      if (c = count) != 0
        find(:first, :offset => rand(c))
      end
    end
  end

  module InstanceMethods
    # Clones the model resetting `created_at/updated_at` attributes, and
    # setting attributes from `changing_attributes` on cloned model.
    def smart_clone(changing_attributes = {})
      clone.tap do |cloned|
        for name, value in changing_attributes
          cloned.send("#{ name }=", value)
        end
        cloned.created_at = nil if cloned.respond_to?(:created_at)
        cloned.updated_at = nil if cloned.respond_to?(:updated_at)
      end
    end

    # Constructs OpenStruct based on the record.
    # Names of methods which will be carried along to resulting OpenStruct can be passed
    # and also initialization hash as for normal OpenStruct constructor.
    def to_ostruct_exposing(*exposed_methods_and_initialize_hashes)
      exposed_attributes = exposed_methods_and_initialize_hashes.select do |arg|
        [ Symbol, String ].include?(arg.class)
      end

      initialize_hash = exposed_methods_and_initialize_hashes.select do |arg|
        arg.is_a?(Hash)
      end.inject({}, &:merge) # combine all hashes just in case
      
      for attr in exposed_attributes
        initialize_hash[attr] = send(attr)
      end
      
      OpenStruct.new(initialize_hash.symbolize_keys)
    end

    # Constructs OpenStruct based on the record.
    # Names of methods which will be carried along to resulting OpenStruct can be passed
    # and also initialization hash as for normal OpenStruct constructor.
    def to_hash_exposing(*exposed_methods_and_initialize_hashes)
      exposed_attributes = exposed_methods_and_initialize_hashes.select do |arg|
        [ Symbol, String ].include?(arg.class)
      end
      
      initialize_hash = exposed_methods_and_initialize_hashes.select do |arg|
        arg.is_a?(Hash)
      end.inject({}, &:merge) # combine all hashes just in case

      for attr in exposed_attributes
        initialize_hash[attr] = send(attr)
      end
      
      initialize_hash.symbolize_keys
    end

    # Returns brief information about model (id or new_record) and truncated
    # `name/title` attribute when such attribute is present.
    # Useful in log messages.
    def short_inspect
      attrs = []
      attrs << ["id", id || "new_record"]

      string_attr = proc { |value| '"' + TextHelpers.truncate(value, :length => 10) + '"' }

      if respond_to?(:name) && name.present?
        attrs << ["name", string_attr[name]]
      elsif respond_to?(:title) && title.present?
        attrs << ["title", string_attr[title]]
      end

      "#<#{ self.class } #{ attrs.map { |name, value| "#{ name }: #{ value }" }.join(", ") }>"
    end

    # Registers object view (when object has :views attribute).
    def hit!
      raise ActiveRecord::MissingAttributeError, "can't hit! #{ self.short_inspect }, missing attribute: views" unless respond_to?(:views)
      self.class.increment_counter(:views, id)
    end

    # Returns all found validation errors + the result of `inspect` so that you
    # from which model these errors came. Again can be useful in logging.
    def inspect_errors
      valid?
      errors.full_messages.join("; ") + " " + inspect
    end

    # Raises exception if record is invalid.
    def valid!
      raise ActiveRecord::RecordInvalid.new(self) if invalid?
    end
  end

  # Replaces Rails default `ActiveRecord::RecordInvalid` exception.
  # When `save!` or `create!` is called for model which can't be validated
  # `ActiveRecord::RecordInvalid` exception is raised.
  # The message of this exception includes the description of validation errors
  # but doesn't say anything about the model for which the validation failed.
  # This `ActiveRecord::RecordInvalid` implementation adds this information to
  # the exception message. Useful in logging, batch processing, etc.
  class RecordInvalid < ::ActiveRecord::ActiveRecordError
    attr_reader :record

    def initialize(record)
      @record = record
      errors = @record.errors.full_messages.join(I18n.t('support.array.words_connector', :default => ', '))
      # short_inspect gives id and name/title
      # so that for existing records it's easy to lookup the record in DB
      # and for new records default to complete inspect
      record_inspect = record.new_record? ? record.inspect : record.short_inspect
      super(I18n.t('activerecord.errors.messages.record_invalid', :errors => errors) + " (record which failed validation: #{ record_inspect })")
    end
  end
end

ActiveRecord::Base.extend(ActiveRecordExtensions::ClassMethods)
ActiveRecord::Base.send(:include, ActiveRecordExtensions::InstanceMethods)

# TODO that's what will_paginate and others do, make sure it couldn't be implemented with +super+ 
#ActiveRecord::Associations::AssociationCollection.class_eval do
#  def sum_with_enumerable_fallback(*args, &block)
#    if args.empty? && block
#      to_a.sum(&block)
#    else
#      sum_without_enumerable_fallback(*args)
#    end
#  end
#
#  alias_method_chain :sum, :enumerable_fallback
#end

ActiveRecord.const_set(:RecordInvalid, ActiveRecordExtensions::RecordInvalid)