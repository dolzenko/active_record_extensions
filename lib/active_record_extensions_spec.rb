# prerequisites
require "active_record"
require "active_record/validations"

# tested code
require File.expand_path("../active_record_extensions", __FILE__)
puts  File.expand_path("../active_record_extensions", __FILE__)

describe ActiveRecordExtensions do
  describe "ClassMethods" do
    describe "validates_url_format_of" do
      let(:model) do
        Class.new do
          extend ActiveRecordExtensions::ClassMethods
          include ActiveModel::Validations
          attr_accessor :url
        end
      end

      it "doesn't add validation error when proper URL is supplied for validated attribute" do
        model.class_eval do
          validates_url_format_of :url
        end

        model.new.tap { |m| m.url = "http://example.com" }.should be_valid
      end

      it "adds validation error when invalid URL is supplied for validated attribute" do
        model.class_eval do
          validates_url_format_of :url
        end

        model.new.tap { |m| m.url = "qweasdzcx" }.should_not be_valid
      end
    end

    describe "validates_email_format_of" do
      let(:model) do
        Class.new do
          extend ActiveRecordExtensions::ClassMethods
          include ActiveModel::Validations
          attr_accessor :email
          
          def self.name # make ActionModel happy
            "Model"
          end
        end
      end

      it "doesn't add validation error when proper email is supplied for validated attribute" do
        model.class_eval do
          validates_email_format_of :email
        end

        model.new.tap { |m| m.email = "dolzenko@gmail.com" }.should be_valid
      end

      it "adds validation error when invalid email is supplied for validated attribute" do
        model.class_eval do
          validates_email_format_of :email
        end

        model.new.tap { |m| m.email = "zxcasdqwe" }.should_not be_valid
      end
    end

    describe "my_quote_columns" do
      let(:model) do
        Class.new.tap do |model|
          model.extend(ActiveRecordExtensions::ClassMethods)
          model.stub(:connection).and_return(stub("connection"))
        end
      end

      it "quotes single column prepending quoted table name" do
        model.should_receive(:table_name).and_return("models")
        
        model.connection.should_receive(:quote_table_name).
                          with("models").
                          and_return("`models`")

        model.connection.should_receive(:quote_column_name).
                          with("id").
                          and_return("`id`")

        model.my_quote_columns("id").should == "`models`.`id`"
      end

#      columns = %w(email url subdomain).map do |name|
#        ActiveRecord::ConnectionAdapters::Column.new(name, nil)
#      end
#      model.stub(:columns).and_return(columns)
#
#      connection = stub("connection")
#      connection.stub


    end

    describe "strictly_belongs_to" do
      let(:model) do
        Class.new.tap do |model|
          model.extend(ActiveRecordExtensions::ClassMethods)
        end
      end

      it "calls underlying belongs_to class method passing supplied belongs_to options" do
        model.stub(:validates_presence_of)
        model.should_receive(:belongs_to).with(:post, :foreign_key => :post_id)

        model.class_eval do
          strictly_belongs_to :post, :foreign_key => :post_id
        end
      end

      it "calls underlying validates_presence_of class method with proper default foreign key" do
        model.stub(:belongs_to)
        model.should_receive(:validates_presence_of).with(:post_id, {})

        model.class_eval do
          strictly_belongs_to :post
        end
      end

      it "calls underlying validates_presence_of class method with proper supplied foreign key" do
        model.stub(:belongs_to)
        model.should_receive(:validates_presence_of).with(:weirdo_foreign_key, {})

        model.class_eval do
          strictly_belongs_to :post, :foreign_key => :weirdo_foreign_key
        end
      end

      it "calls underlying validates_presence_of class method with proper default foreign key for polymorphic association" do
        model.stub(:belongs_to)
        model.should_receive(:validates_presence_of).with(:entity_id, :entity_type, {})

        model.class_eval do
          strictly_belongs_to :entity, :polymorphic => true 
        end
      end

      it "calls delegate when :delegating option is supplied" do
        model.stub(:belongs_to)
        model.stub(:validates_presence_of)
        model.should_receive(:delegate).with(:post_meth, :to => "post")

        model.class_eval do
          strictly_belongs_to :post, :delegating => :post_meth
        end
      end

      it "calls delegate when :delegating option is supplied with array of methods and last hash of options" do
        model.stub(:belongs_to)
        model.stub(:validates_presence_of)
        model.should_receive(:delegate).with(:post_meth1,
                                             :post_meth2,
                                             :to => "post",
                                             :allow_nil => true)

        model.class_eval do
          strictly_belongs_to :post, :delegating => [ :post_meth1,
                                                      :post_meth2,
                                                      { :allow_nil => true } ]
        end
      end
    end
  end
  describe "InstanceMethods" do
    describe "smart_clone" do
      it "clones required attributes" do
        model = Struct.new(:wont_change, :will_change)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        original = model.new("wont_change value", "will_change value")

        cloned = original.smart_clone(:will_change => "new will_change value")

        cloned.wont_change.should == "wont_change value"
        cloned.will_change.should == "new will_change value"
      end

      it "sets created_at/updated_at attributes to nil when they are present" do
        model = Struct.new(:created_at, :updated_at)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        original = model.new(1, 2)

        cloned = original.smart_clone

        cloned.created_at.should == nil
        cloned.updated_at.should == nil
      end
    end

    describe "to_ostruct_exposing" do
      it "creates OpenStruct object with specified attributes copied from model" do
        model = Struct.new(:created_at, :updated_at)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        ostruct = model.new(1, 2).to_ostruct_exposing(:created_at)
        ostruct.should respond_to(:created_at)
        ostruct.should_not respond_to(:updated_at)
      end

      it "makes attributes specified in initialization hash (last argument) available on returned OpenStruct" do
        model = Struct.new(:created_at, :updated_at)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        ostruct = model.new(1, 2).to_ostruct_exposing(:created_at, { :some_attr => 42 })
        ostruct.some_attr.should == 42
      end
    end

    describe "to_hash_exposing" do
      it "creates Hash with specified attributes copied from model" do
        model = Struct.new(:created_at, :updated_at)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        hash = model.new(1, 2).to_hash_exposing(:created_at)
        
        hash.should have_key(:created_at)
        hash[:created_at].should == 1

        hash.should_not have_key(:updated_at)
      end

      it "makes attributes specified in initialization hash (last argument) available on returned Hash" do
        model = Struct.new(:created_at, :updated_at)

        model.send(:include, ActiveRecordExtensions::InstanceMethods)

        hash = model.new(1, 2).to_hash_exposing(:created_at, { :some_attr => 42 })
        
        hash[:some_attr].should == 42
      end
    end

    describe "RecordInvalid" do
      it "is installed properly" do
        ActiveRecord.const_get(:RecordInvalid).should == ActiveRecordExtensions::RecordInvalid
      end
    end
  end
end
