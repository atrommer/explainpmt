class Project < ActiveRecord::Base
  has_and_belongs_to_many :users
  has_many :story_cards
  has_many :milestones
  
  validates_presence_of :name
end