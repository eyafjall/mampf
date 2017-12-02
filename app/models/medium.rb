# Medium class
class Medium < ApplicationRecord
  belongs_to :teachable, polymorphic: true
  has_many :medium_tag_joins
  has_many :tags, through: :medium_tag_joins
  has_many :links, dependent: :destroy
  has_many :linked_media, through: :links, dependent: :destroy
  validates :sort, presence: true,
                   inclusion: { in: :sort_enum }
  validates :question_id, presence: true, uniqueness: true, if: :keks_question?
  validates :author, presence: true
  validates :title, presence: true, uniqueness: true
  validate :nonempty_content?
  validates :video_file_link, http_url: true, if: :video_file_content?
  validates :video_thumbnail_link, http_url: true, if: :video_content?
  validates :video_stream_link, http_url: true, if: :video_stream_content?
  validates :manuscript_link, http_url: true, if: :manuscript_content?
  validates :external_reference_link, http_url: true, if: :external_content?
  validates :extras_link, http_url: true, if: :extra_content?
  validates :width, presence: true,
                    numericality: { only_integer: true,
                                    greater_than_or_equal_to: 100,
                                    less_than_or_equal_to: 8192 },
                    if: :video_content?
  validates :height, presence: true,
                     numericality: { only_integer: true,
                                     greater_than_or_equal_to: 100,
                                     less_than_or_equal_to: 4320 },
                     if: :video_content?
  validates :embedded_width, presence: true,
                             numericality: { only_integer: true,
                                             greater_than_or_equal_to: 100,
                                             less_than_or_equal_to: 8192 },
                             if: :video_stream_content?
  validates :embedded_height, presence: true,
                              numericality: { only_integer: true,
                                              greater_than_or_equal_to: 100,
                                              less_than_or_equal_to: 4320 },
                              if: :video_stream_content?

  validates :length, presence: true,
                     format: { with: /\A[0-9]h[0-5][0-9]m[0-5][0-9]s\z/ },
                     if: :video_content?

  # video_size, manuscript_size are in a format compatible with 'filesize' gem
  validates :video_size, presence: true,
                         format:
                           { with: /\A([\d,.]+)?\s?(?:([kmgtpezy])i)?b\z/i },
                         if: :video_file_content?
  validates :pages, presence: true,
                    numericality: { only_integer: true,
                                    greater_than_or_equal_to: 1,
                                    less_than_or_equal_to: 2000 },
                    if: :manuscript_content?
  validates :manuscript_size, presence: true,
                              format:
                                { with: /\A([\d,.]+)?\s?(?:([kmgtpezy])i)?b\z/i },
                              if: :manuscript_content?
  validates :question_list, presence: true,
                            format: { with: /\A(\d+&)*\d+\z/ },
                            if: :keks_quiz?
  validates :extras_description, presence: true, if: :extra_content?

  after_initialize :set_defaults
  after_save :create_keks_link, if: :keks_link_missing?

  def sort_enum
    %w[Kaviar Erdbeere Sesam Kiwi Reste KeksQuestion KeksQuiz]
  end

  def self.search(params)
    sorts = { '1' => 'Kaviar', '2' => 'Sesam', '3' => 'Kiwi', '4' => 'KeksQuiz',
              '5' => 'Reste' }
    return unless Lecture.exists?(params[:lecture_id]) && (1..5).cover?(params[:module_id].to_i)
    lecture = Lecture.find_by_id(params[:lecture_id])
    teachable = params[:module_id] == '1' ? lecture.lessons : lecture
    media = Medium.where(teachable: teachable,
                         sort: sorts[params[:module_id]]).order(:id)
  end

  def video_aspect_ratio
    return unless height != 0 && width != 0
    width.to_f / height
  end

  def video_scaled_height(new_width)
    return unless height != 0 && width != 0
    (new_width.to_f / video_aspect_ratio).to_i
  end

  def caption
    return heading if heading.present?
    return unless sort == 'Kaviar' && teachable_sort == 'Lesson'
    teachable.section_titles
  end

  def tag_titles
    tags.map(&:title).join(', ')
  end

  def card_header
    teachable.description[:general]
  end

  def card_header_teachable
    return teachable unless teachable_sort == 'Lesson'
    teachable.lecture
  end

  def card_subheader
    return description if description.present?
    return teachable.description[:specific] if
      teachable.description[:specific].present?
    { 'KeksQuestion' => 'KeKs Frage Nr. ' + question_id.to_s,
      'KeksQuiz' => 'KeksQuiz', 'Sesam' => 'SeSAM Video',
      'Kiwi' => 'KIWi Video' }[sort]
  end

  def card_subheader_teachable
    return if description.present? || teachable.description[:specific].nil?
    teachable
  end

  def sort_de
    { 'Kaviar' => 'KaViaR', 'Sesam' => 'SeSAM',
      'KeksQuestion' => 'Keks-Frage', 'KeksQuiz' => 'Keks-Quiz',
      'Reste' => 'RestE', 'Erdbeere' => 'ErDBeere', 'Kiwi' => 'KIWi' }[sort]
  end

  def question_ids
    return if question_list.nil?
    question_list.split('&').map(&:to_i)
  end

  def teachable_sort
    teachable.class.name
  end

  def teachable_sort_de
    { 'Course' => 'Kurs', 'Lecture' => 'Vorlesung',
      'Lesson' => 'Sitzung' }[teachable_sort]
  end

  def related_to_lecture?(lecture)
    case teachable_sort
    when 'Course'
      return true if teachable == lecture.course
    when 'Lecture'
      return true if teachable == lecture
    when 'Lesson'
      return true if teachable.lecture == lecture
    end
    false
  end

  def related_to_lectures?(lectures)
    lectures.map { |l| related_to_lecture?(l) }.include?(true)
  end

  scope :KeksQuestion, -> { where(sort: 'KeksQuestion') }
  scope :Kaviar, -> { where(sort: 'Kaviar') }

  private

  def set_defaults
    self.sort = 'Kaviar' if new_record?
  end

  def video_content?
    video_stream_link.present? || video_file_link.present?
  end

  def video_file_content?
    video_file_link.present?
  end

  def video_stream_content?
    video_stream_link.present?
  end

  def manuscript_content?
    manuscript_link.present?
  end

  def external_content?
    external_reference_link.present?
  end

  def extra_content?
    extras_link.present?
  end

  def nonempty_content?
    return true if video_stream_link.present? ||
                   video_file_link.present? ||
                   manuscript_link.present? ||
                   external_reference_link.present? ||
                   keks_question?
    errors.add(:base, 'empty content')
    false
  end

  def keks_question?
    sort == 'KeksQuestion'
  end

  def keks_quiz?
    sort == 'KeksQuiz'
  end

  def keks_link_missing?
    return false unless sort == 'KeksQuestion' && !external_reference_link.present?
    true
  end

  def create_keks_link
    update(external_reference_link:
             'https://keks.mathi.uni-heidelberg.de/hitme#hide-options' \
             '#hide-categories#question=' + question_id.to_s)
  end

end
