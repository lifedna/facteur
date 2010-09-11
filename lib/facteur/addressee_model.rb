module Facteur
  module AddresseeModel
    def self.included(receiver)
      receiver.class_exec do
        include InstanceMethods
        
        has_many :mailboxes, :as => :addressee
        has_many :messages_sent, :class_name => "Message", :foreign_key => "author_id"
        
        # the addressee's mailboxes are created after its creation
        after_create :create_mailboxes
      end
      
      receiver.extend ClassMethods
    end
    
    module ClassMethods
      
      # Define a mailbox. The following options are available:
      # <tt>:default</tt>:: defines the default mailbox. You must choose one default mailbox
      def mailbox(name, options={})
        mailbox = {:name => name}
        mailbox.merge! options
        mailboxes << mailbox
        all.each do |addressee|
          addressee.create_mailbox(name, options)
        end
      end
      
      # Returns the mailboxes defined for the class
      def mailboxes
        @mailboxes ||= []
      end
    end
    
    module InstanceMethods
      
      # Sends a message to one or many addressees. The following options are available:
      #
      # <tt>:to</tt>:: the addressee or the list of addressees (mandatory)
      # <tt>:in</tt>:: the name of the mailbox in which the message is posted (mandatory)
      # <tt>:body</tt>:: the message's body (mandatory)
      #
      # Usage :
      #
      #     # send a message to one addressee
      #     @john.send_message('message contents', :to => @peter, :in => :private_mailbox)
      #
      #     # send a message to many addressees
      #     @john.send_message('message contents', :to => [@peter, @james], :in => :private_mailbox)
      def send_message(message, options)
        options[:body] = message
        if options[:to].is_a? Array
          options[:to].each do |addressee|
            send_message_to(addressee, options[:in], options[:body])
          end
        else
          send_message_to(options[:to], options[:in], options[:body])
        end
      end
      
      # Creates a new mailbox. if a mailbox with the same name already exists, it fails and returns false. If succeeded, it creates an accessor for the new mail box and returns true.
      # Example :
      #
      #     class User < ActiveRecord::base
      #        include Facteur::AddresseeModel
      #        
      #        mailbox :private_mailbox
      #     end
      #
      # The previous declaration will add : User#private_mailbox
      #     
      #     # supposing that a name field exists
      #     user = User.new(:name => 'John')
      #     user.create_mailbox :public_mailbox #=> return true
      #     user.create_mailbox :private_mailbox #=> return false
      def create_mailbox(name, options={})
        mailbox = Mailbox.new(:name => name.to_s)
        mailbox.addressee = self
        return false if mailbox.save == false
        
        @default_mailbox = name if options[:default]
        self.class.class_eval do
          define_method(name) do
            self.mailboxes.where(:name => name.to_s).first
          end
        end
        true
      end
      
      # Creates a new mailbox. if a mailbox with the same name already exists, it raises an exception. If succeeded, it creates an accessor for the new mail box and returns the created mailbox.
      def create_mailbox!(name, options={})
        if create_mailbox(name, options) == false
          raise "Mailboxes names must be unique. Can't create '#{name}'"
        end
        self.send "#{name}"
      end
      
      private
      
      # creates the mailboxes defined in the configuration
      def create_mailboxes
        self.class.mailboxes.each do |mailbox|
          options = {}.merge(mailbox)
          name = options.delete(:name)
          create_mailbox!(name, options)
        end
      end
      
      # send a message to an addressee
      def send_message_to(addressee, mailbox_name, contents)
        return false if addressee.nil? or contents.nil?
        
        mailbox_name = @default_mailbox if mailbox_name.nil?
        return false if mailbox_name.nil?
        
        message = Message.new
        message.author = self
        message.mailbox = addressee.send(mailbox_name)
        message.body = contents
        message.save
      end
    end
  end
end
