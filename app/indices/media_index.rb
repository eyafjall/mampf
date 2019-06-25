ThinkingSphinx::Index.define :medium, :with => :real_time do
  # fields
  indexes type
  indexes teachable_type

  # attributes
  has editor_ids,  type: integer, multi: true
  has tag_ids, type: integer, multi: true
  has teachable_id, type: integer
end