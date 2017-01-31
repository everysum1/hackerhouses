require 'elasticsearch/model'

class Property < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  validates :title, :presence => true
  validates :description, :presence => true
  validates :street, :presence => true
  validates :city, :presence => true
  validates :state, :presence => true
  validates :price, :presence => true
  geocoded_by :address
  after_validation :geocode, :if => :street_changed? || :city_changed? || :state_changed?
  ac_field :title, search_fields: [:title, :city]
  
  def address
    [street, city, state].compact.join(', ')
  end

  def self.search(query)
    __elasticsearch__.search(
      {
        query: {
          multi_match: {
            query: query,
            fields: ['title^10', 'description', 'street', 'city']
          }
        }
      }
    )
  end

  settings index: { number_of_shards: 1 } do
    mappings dynamic: 'false' do
      indexes :title, analyzer: 'english'
      indexes :description, analyzer: 'english'
      indexes :city, analyzer: 'english'
    end
  end

end

# Delete the previous properties index in Elasticsearch
Property.__elasticsearch__.client.indices.delete index: Property.index_name rescue nil

# Create the new index with the new mapping
Property.__elasticsearch__.client.indices.create \
  index: Property.index_name,
  body: { settings: Property.settings.to_hash, mappings: Property.mappings.to_hash }

Property.import
