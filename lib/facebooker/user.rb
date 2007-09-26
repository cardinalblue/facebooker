require 'facebooker/model'
require 'facebooker/affiliation'
require 'facebooker/work_info'

module Facebooker
  # 
  # Holds attributes and behavior for a Facebook User
  class User
    include Model
    class Status
      include Model
      attr_accessor :message, :time
    end
    FIELDS = [:status, :political, :pic_small, :name, :quotes, :is_app_user, :tv, :profile_update_time, :meeting_sex, :hs_info, :timezone, :relationship_status, :hometown_location, :about_me, :wall_count, :significant_other_id, :pic_big, :music, :uid, :work_history, :sex, :religion, :notes_count, :activities, :pic_square, :movies, :has_added_app, :education_history, :birthday, :first_name, :meeting_for, :last_name, :interests, :current_location, :pic, :books, :affiliations]
    attr_accessor :id, :session
    populating_attr_accessor *FIELDS
    attr_reader :affiliations
    hash_settable_accessor :current_location, Location
    hash_settable_accessor :hometown_location, Location
    hash_settable_accessor :hs_info, EducationInfo::HighschoolInfo
    hash_settable_accessor :status, Status
    hash_settable_list_accessor :affiliations, Affiliation
    hash_settable_list_accessor :education_history, EducationInfo
    hash_settable_list_accessor :work_history, WorkInfo

    # Can pass in these two forms:
    # id, session, (optional) attribute_hash
    # attribute_hash
    def initialize(*args)
      if (args.first.kind_of?(String) || args.first.kind_of?(Integer)) && args[1].kind_of?(Session)
        @id = Integer(args.shift)
        @session = args.shift
      end
      if args.last.kind_of?(Hash)
        populate_from_hash!(args.pop)
      end      
    end


    # 
    # Set the list of friends, given an array of User objects.  If the list has been retrieved previously, will not set
    def friends=(list_of_friends)
      @friends ||= list_of_friends
    end
    
    ##
    # Retrieve friends
    def friends
      @friends ||= @session.post('facebook.friends.get').map do |uid|
        User.new(uid, @session)
      end
    end
    
    ###
    # Retrieve friends with user info populated
    # Subsequent calls will be retrieved from memory.
    # Optional: list of fields to retrieve as symbols
    def friends!(*fields)
      @friends ||= session.post('facebook.users.getInfo', :fields => FIELDS.reject{|field_name| !fields.empty? && !fields.include?(field_name)}.join(','), :uids => friends.map{|f| f.id}.join(',')).map do |hash|  
        User.new(hash['uid'], session, hash)
      end
    end
    
    def populate
      results = session.post('facebook.users.getInfo', :fields => FIELDS.join(','), :uids => id)
      populate_from_hash!(results.first)
    end
    
    def friends_with?(user_or_id)
      friends.map{|f| f.to_i}.include?(user_or_id.to_i)  
    end
    
    def friends_with_this_app
      @friends_with_this_app ||= session.post('facebook.friends.getAppUsers').map do |uid|
        User.new(uid, session)
      end
    end
    
    def groups(gids = [])
      args = gids.empty? ? {} : {:gids => gids}
      @groups ||= session.post('facebook.groups.get', args).map do |hash|
        group = Group.from_hash(hash)
        group.session = session
        group
      end
    end
    
    def notifications
      @notifications ||= Notifications.from_hash(session.post('facebook.notifications.get'))
    end
    
    def publish_story(story)
      publish(story)
    end
    
    def publish_action(action)
      publish(action)
    end
    
    def albums
      @albums ||= session.post('facebook.photos.getAlbums', :uid => self.id).map do |hash|
        Album.from_hash(hash)
      end
    end
    
    def create_album(params)
      @album = Album.from_hash(session.post('facebook.photos.createAlbum', params))
    end

    def profile_fbml
      session.post('facebook.profile.getFBML', :uid => @id)  
    end    
    
    def profile_fbml=(markup)
      session.post('facebook.profile.setFBML', :uid => @id, :markup => markup)      
    end
    
    # Returns the user's id as an integer
    def to_i
      id
    end
    
    private
    def publish(feed_story_or_action)
      session.post(Facebooker::Feed::METHODS[feed_story_or_action.class.name.split(/::/).last], feed_story_or_action.to_params) == "1" ? true : false
    end
    
  end  
end
