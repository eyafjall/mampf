class MediumSerializer
  include FastJsonapi::ObjectSerializer
  attribute :value, &:id
  attribute :text, &:extended_label
end