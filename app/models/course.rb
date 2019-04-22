# Course class
class Course < ApplicationRecord
  include ApplicationHelper
  has_many :lectures, dependent: :destroy

  # tags are notions that treated in the course
  # e.g.: vector space, linear map are tags for the course 'Linear Algebra 1'
  has_many :course_tag_joins, dependent: :destroy
  has_many :tags, through: :course_tag_joins

  has_many :media, as: :teachable

  # users in this context are users who have subscribed to this course
  has_many :course_user_joins, dependent: :destroy
  has_many :users, through: :course_user_joins

  # preceding courses are courses that this course is based upon
  has_many :course_self_joins, dependent: :destroy
  has_many :preceding_courses, through: :course_self_joins

  # editors are users who have the right to modify its content
  has_many :editable_user_joins, as: :editable, dependent: :destroy
  has_many :editors, through: :editable_user_joins, as: :editable,
                     source: :user

  validates :title, presence: { message: 'Titel muss vorhanden sein.' },
                    uniqueness: { message: 'Titel ist bereits vergeben.' }
  validates :short_title,
            presence: { message: 'Kurztitel muss vorhanden sein.' },
            uniqueness: { message: 'Kurztitel ist bereits vergeben.' }

  # some information about media and lectures are cached
  # to find out whether the cache is out of date, always touch'em after saving
  after_save :touch_media
  after_save :touch_lectures_and_lessons

  # The next methods coexist for lectures and lessons as well.
  # Therefore, they can be called on any *teachable*

  def course
    self
  end

  def lecture
  end

  def lesson
  end

  def media_scope
    self
  end

  def selector_value
    'Course-' + id.to_s
  end

  def to_label
    title
  end

  def compact_title
    short_title
  end

  def title_for_viewers
    Rails.cache.fetch("#{cache_key}/title_for_viewers") do
      short_title
    end
  end

  def long_title
    title
  end

  def card_header
    title
  end

  def published?
    true
  end

  def card_header_path(user)
    return unless user.courses.include?(self)
    course_path
  end

  # only irrelevant courses can be deleted
  def irrelevant?
    lectures.empty? && media.empty? && id.present?
  end

  def published_lectures
    lectures.published
  end

  def restricted?
    false
  end

  # The next methods return if there are any media in the Kaviar, Sesam etc.
  # projects that are associated to this course *with inheritance*
  # These methods make use of caching.

  def kaviar?
    project?('kaviar')
  end

  def sesam?
    project?('sesam')
  end

  def keks?
    project?('keks')
  end

  def erdbeere?
    project?('erdbeere')
  end

  def kiwi?
    project?('kiwi')
  end

  def nuesse?
    project?('nuesse')
  end

  def script?
    project?('script')
  end

  def reste?
    project?('reste')
  end

  # The next methods return if there are any media in the Kaviar, Sesam etc.
  # projects that are associated to this course *without inheritance*
  # These methods make use of caching.

  def strict_kaviar?
    strict_project?('kaviar')
  end

  def strict_sesam?
    strict_project?('sesam')
  end

  def strict_keks?
    strict_project?('keks')
  end

  def strict_erdbeere?
    strict_project?('erdbeere')
  end

  def strict_kiwi?
    strict_project?('kiwi')
  end

  def strict_nuesse?
    strict_project?('nuesse')
  end

  def strict_script?
    strict_project?('script')
  end

  def strict_reste?
    strict_project?('reste')
  end

  # returns if there are any media associated to this course
  # which are not of type kaviar *with inheritance*
  def available_extras
    hash = { 'sesam' => sesam?, 'keks' => keks?,
             'erdbeere' => erdbeere?, 'kiwi' => kiwi?, 'nuesse' => nuesse?,
             'script' => script?, 'reste' => reste? }
    hash.keys.select { |k| hash[k] == true }
  end

  # returns an array with all types of media that are associated to this course
  # *with inheritance*
  def available_food
    kaviar_info = kaviar? ? ['kaviar'] : []
    kaviar_info.concat(available_extras)
  end

  def lectures_by_date
    lectures.to_a.sort do |i, j|
      j.term.begin_date <=> i.term.begin_date
    end
  end

  def published_lectures_by_date
    published_lectures.to_a.sort do |i, j|
      j.term.begin_date <=> i.term.begin_date
    end
  end

  # extracts  the id of the lecture that the user has chosen as
  # primary lecture for this module
  # (that is the one that has the first position in the lectures carousel in
  # the course view)
  # Example:
  # course.extras({"name"=>"John Smith", "course-3"=>"1",
  #  "primary_lecture-3"=>"3", "lecture-3"=>"1"})
  # {"primary_lecture_id"=>3}
  def extras(user_params)
    modules = {}
    primary_id = user_params['primary_lecture-' + id.to_s]
    modules['primary_lecture_id'] = primary_id.to_i.zero? ? nil : primary_id.to_i
    modules
  end

  # returns all items related to all lectures associated to this course
  def items
    lectures.collect(&:items).flatten
  end

  # returns the lecture which gets to sit on top in the lecture carousel in the
  # lecture view
  def front_lecture(user, active_lecture_id)
    # make sure the front lecture is subscribed by the user
    if subscribed_lectures(user).map(&:id).include?(active_lecture_id)
      return Lecture.find_by_id(active_lecture_id)
    end
    primary_lecture(user)
  end

  def primary_lecture(user)
    user_join = CourseUserJoin.where(course: self, user: user)
    return if user_join.empty?
    Lecture.find_by_id(user_join.first.primary_lecture_id)
  end

  def subscribed_lectures(user)
    course.lectures & user.lectures
  end

  def to_be_authorized_lectures(user)
    published_lectures.select(&:restricted?) -
      subscribed_lectures(user)
  end

  def subscribed_lectures_by_date(user)
    subscribed_lectures(user).to_a.sort do |i, j|
      j.term.begin_date <=> i.term.begin_date
    end
  end

  def subscribed_by?(user)
    user.courses.include?(self)
  end

  def edited_by?(user)
    return true if editors.include?(user)
    false
  end

  # a course is addable by the user if the user is an editor or teacher of
  # this course or a lecture of this course
  def addable_by?(user)
    in?(user.edited_or_given_courses_with_inheritance)
  end

  # a course is removable by the user if the user is an editor of this course
  def removable_by?(user)
    in?(user.edited_courses)
  end

  # returns the ARel of all media that are associated to the course
  # by inheritance (i.e. directly and media which are associated to lectures or
  # lessons associated to this course)
  def media_with_inheritance
    Rails.cache.fetch("#{cache_key}/media_with_inheritance") do
      Medium.proper.where(teachable: self)
        .or(Medium.proper.where(teachable: self.lectures))
        .or(Medium.proper.where(teachable: Lesson.where(lecture: self.lectures)))
    end
  end

  def media_items_with_inheritance
    media_with_inheritance.collect do |m|
      m.items_with_references.collect { |i| [i[:title_within_course], i[:id]] }
    end
                          .reduce(:concat)
  end

  def sections
    lectures.collect(&:sections).flatten
  end

  # returns an array of teachables determined  by the search params
  # search_params is a hash with keys :all_teachables, :teachable_ids
  # teachable ids is an array made up of strings composed of 'lecture-'
  # or 'course-' followed by the id
  # search is done with inheritance
  def self.search_teachables(search_params)
    unless search_params[:all_teachables] == '0'
      return Course.all + Lecture.all + Lesson.all
    end
    courses = Course.where(id: Course.search_course_ids(search_params))
    inherited_lectures = Lecture.where(course: courses)
    selected_lectures = Lecture.where(id: Course
                                            .search_lecture_ids(search_params))
    lectures = (inherited_lectures + selected_lectures).uniq
    lessons = lectures.collect(&:lessons).flatten
    courses + lectures + lessons
  end

  def self.search_lecture_ids(search_params)
    teachable_ids = search_params[:teachable_ids] || []
    teachable_ids.select { |t| t.start_with?('lecture') }
                 .map { |t| t.remove('lecture-') }
  end

  def self.search_course_ids(search_params)
    teachable_ids = search_params[:teachable_ids] || []
    teachable_ids.select { |t| t.start_with?('course') }
                 .map { |t| t.remove('course-') }
  end

  # returns the array of courses that can be edited by the given user,
  # together with a string made up of 'Course-' and their id
  # Is used in options_for_select in form helpers.
  def self.editable_selection(user)
    if user.admin?
      return Course.order(:title)
                   .map { |c| [c.title_for_viewers, 'Course-' + c.id.to_s] }
    end
    Course.includes(:editors, :editable_user_joins)
          .order(:title).select { |c| c.edited_by?(user) }
          .map { |c| [c.title_for_viewers, 'Course-' + c.id.to_s] }
  end

  # returns the array of all tags (sorted by title) together with
  # their ids
  def self.select_by_title
    Course.all.to_a.natural_sort_by(&:title).map { |t| [t.title, t.id] }
  end

  def mc_questions_count
    Rails.cache.fetch("#{cache_key}/mc_questions_count") do
      Question.where(teachable: [self] + [lectures.published],
                     independent: true,
                     released: ['all', 'users'])
              .select { |q| q.answers.count > 1 }
              .count
    end
  end

  def enough_questions?
    mc_questions_count >= 10
  end

  def create_random_quiz!
    question_ids = Question.where(teachable: [self] + [lectures.published],
                                  independent: true,
                                  released: ['all', 'users'])
                           .select { |q| q.answers.count > 1 }
                           .sample(5).map(&:id)
    quiz_graph = QuizGraph.build_from_questions(question_ids)
    quiz = Quiz.new(description: "Zufallsquiz #{course.title} #{Time.now}",
                    level: 1,
                    quiz_graph: quiz_graph,
                    sort: 'RandomQuiz')
    quiz.save
    return quiz.errors unless quiz.valid?
    quiz
  end

  private

  # looks in the cache if there are any media associated *with inheritance*
  # to this course and a given project (kaviar, semsam etc.)
  def project?(project)
    Rails.cache.fetch("#{cache_key}/#{project}") do
      Medium.where(sort: sort[project]).includes(:teachable)
            .any? { |m| m.teachable.present? && m.teachable.course == self }
    end
  end

  # looks in the cache if there are any media associated *without_inheritance*
  # to this course and a given project (kaviar, semsam etc.)
  def strict_project?(project)
    Rails.cache.fetch("#{cache_key}/strict_#{project}") do
      Medium.where(sort: sort[project], teachable: self).any?
    end
  end

  def sort
    { 'kaviar' => ['Kaviar'], 'sesam' => ['Sesam'], 'kiwi' => ['Kiwi'],
      'keks' => ['Quiz'], 'nuesse' => ['Nuesse'],
      'erdbeere' => ['Erdbeere'], 'script' => ['Script'], 'reste' => ['Reste'] }
  end

  def course_path
    Rails.application.routes.url_helpers.course_path(self)
  end

  def touch_media
    media_with_inheritance.update_all(updated_at: Time.now)
  end

  def touch_lectures_and_lessons
    lectures.update_all(updated_at: Time.now)
    Lesson.where(lecture: lectures).update_all(updated_at: Time.now)
  end
end
