class Memory < ApplicationRecord
  belongs_to :superseded_by, class_name: "Memory", optional: true
end
