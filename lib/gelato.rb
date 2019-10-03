require "pry"

class Gelato < ActiveRecord::Base
  has_many :orders
  has_many :users, through: :orders

  def current_stock
    Gelato.all.first.stock
  end

  def self.get_flavours
    # Gelato.all.map(&:flavour)
    Gelato.all
  end

  def get_gelato_flavour_from_order(order)
    gelato_id = order.gelato_id
    # get_flavours.select{ |flavour| flavour == }
  end
end
