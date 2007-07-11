class Iteration < ActiveRecord::Base
  belongs_to :project
  has_many :stories do

    def total_points
      self.inject(0) { |res,s| res + s.points }
    end

    def completed_points
      completed_stories = self.select { |s| s.status.complete? }
      completed_stories.inject(0) { |res,s| res + s.points }
    end

    def remaining_points
      total_points - completed_points
    end
  end

  validates_inclusion_of :length, :in => 1..99,
                         :message => 'must be a number between 1 and 99'
  validates_inclusion_of :budget, :in => 1..999, :allow_nil => true,
                         :message => 'must be a number between 1 and 999 ' +
                                     '(or blank)'
  validates_presence_of :start_date
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => "project_id"

  def stop_date
    start_date + length.to_i - 1
  end

  def remaining_resources
    (budget || 0) - stories.total_points
  end

  def points_by_user
      stories.inject( Hash.new( 0 ) ) do |hsh, story|
            hsh[ story.user_id ] += story.points      
            hsh    
     end  
  end
  
  def current?
    today = Time.now.at_midnight
    ( start_date.to_time <= today ) and ( stop_date.to_time >= today ) 
  end

  def future?
    tomorrow = Time.now.tomorrow.at_midnight
    start_date.to_time >= tomorrow
  end

  def past?
    today = Time.now.at_midnight
    stop_date.to_time < today
  end

  def self.find_stories(iteration_id)
  	Story.find(:all, :include => [:initiative, :project, :owner], :conditions => "stories.iteration_id = #{iteration_id}")
  end
  
  protected

  def after_destroy
    Story.update_all("iteration_id = NULL", ["iteration_id = ?",self.id])
  end

  def validate
    ensure_iteration_belongs_to_project
    ensure_no_overlap unless project.nil?
  end

  def ensure_iteration_belongs_to_project
    if project.nil?
      errors.add_to_base('The iteration is not assigned to a project!')
    end
  end

  def ensure_no_overlap
    found_overlap = false
    overlaps = nil
    set_overlap_found = Proc.new { |i|
      found_overlap = true
      overlaps = i
    }
    project.iterations(true).each do |iteration|
      unless iteration.id == id
        if iteration.stop_date <= stop_date &&
          iteration.stop_date >= start_date
          set_overlap_found.call(iteration)
          break
        elsif iteration.start_date >= start_date &&
          iteration.start_date <= stop_date
          set_overlap_found.call(iteration)
          break
        elsif iteration.start_date >= start_date &&
          iteration.stop_date <= stop_date
          set_overlap_found.call(iteration)
          break
        elsif iteration.start_date <= start_date &&
          iteration.stop_date >= stop_date
          set_overlap_found.call(iteration)
          break
        end
      end
    end
    if found_overlap
      errors.add(:start_date, "causes an overlap with #{overlaps.length}-day " +
                 "iteration starting on " +
                 "#{overlaps.start_date.strftime("%m/%d/%Y")}.")
    end
  end
end