class User < ActiveRecord::Base
  has_many :orders
  has_many :gelatos, through: :orders
end
