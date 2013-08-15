module ActiveModel
  module SecureAttribute
    extend ActiveSupport::Concern

    class << self
      attr_accessor :min_cost
    end
    self.min_cost = false

    module ClassMethods
      def method_missing(meth, *args, &block)
        if meth.to_s =~ /^has_secure_(.+)$/
          has_secure_attribute($1, *args, &block)
        else
          super
        end
      end

      def has_secure_attribute(meth, *args, &block)
        attribute_sym = meth.to_sym
        attr_reader attribute_sym # setter is defined later on
        options = {:validations => true, :protect_setter_for_digest => false}
        options.merge! args[0] unless args.blank?
        if options[:validations]
          validates attribute_sym,                          confirmation: true, if: lambda { |m| m.send(attribute_sym).present? }
          validates attribute_sym,                          presence: true,     on: :create
          validates "#{attribute_sym}_confirmation".to_sym, presence: true,     if: lambda { |m| m.send(attribute_sym).present? }
          before_create { raise "#{attribute_sym}_digest missing on new record" if send("#{attribute_sym}_digest").blank? }
        end

        define_setter(attribute_sym)
        protect_setter_for_digest(attribute_sym) if options[:protect_setter_for_digest]

        define_authenticate_method(attribute_sym)
      end

      def define_setter(attribute_sym)
        define_method "#{attribute_sym.to_s}=" do |unencrypted_value|
          unless unencrypted_value.blank?
            instance_variable_set("@#{attribute_sym.to_s}".to_sym, unencrypted_value)
            cost = ActiveModel::SecureAttribute.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine::DEFAULT_COST
            send("#{attribute_sym.to_s}_digest=".to_sym, BCrypt::Password.create(unencrypted_value, cost: cost))
          end
        end
      end

      def protect_setter_for_digest(attribute_sym)
        define_method "#{attribute_sym}_digest=" do |value|
          write_attribute "#{attribute_sym}_digest".to_sym, value
        end
        protected "#{attribute_sym}_digest=".to_sym
      end

      def define_authenticate_method(attribute_sym)
        define_method "authenticate_#{attribute_sym}" do |value|
          BCrypt::Password.new(send("#{attribute_sym}_digest")) == value && self
        end
      end

      protected :has_secure_attribute
      protected :define_setter
      protected :protect_setter_for_digest
      protected :define_authenticate_method
    end

  end
end

ActiveRecord::Base.send :include, ActiveModel::SecureAttribute