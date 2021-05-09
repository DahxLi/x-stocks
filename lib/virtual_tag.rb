# frozen_string_literal: true

# Allows to filter stocks using conditions
class VirtualTag
  attr_reader :name, :description, :fa_icon, :sort_order

  def initialize(name, description, ruby_expression, db_expression, fa_icon, sort_order = nil)
    @name = name
    @description = description
    @ruby_expression = ruby_expression
    @db_expression = db_expression
    @fa_icon = fa_icon
    @sort_order = sort_order
  end

  def self.all
    ALL
  end

  def self.find(name)
    all.detect { |tag| tag.name == name }
  end

  def find_stock_ids(user)
    @db_expression.call(user)
  end

  def eligible?(position)
    @ruby_expression.call(position)
  end

  ALL = [
    VirtualTag.new('Dividend Achiever', '≥ 10 years of Dividend Growth', ->(position) { position.stock.dividend_growth_years && position.stock.dividend_growth_years >= 10 }, ->(_user) { XStocks::AR::Stock.where('dividend_growth_years >= 10') }, 'fa-chart-line'),
    VirtualTag.new('Dividend Contender', '10-24 years of Dividend Growth', ->(position) { position.stock.dividend_growth_years && position.stock.dividend_growth_years >= 10 && position.stock.dividend_growth_years < 25 }, ->(_user) { XStocks::AR::Stock.where('dividend_growth_years >= 10 and dividend_growth_years < 25') }, 'fa-chart-line'),
    VirtualTag.new('Dividend Champion', '≥ 25 years of Dividend Growth', ->(position) { position.stock.dividend_growth_years && position.stock.dividend_growth_years >= 25 }, ->(_user) { XStocks::AR::Stock.where('dividend_growth_years >= 25') }, 'fa-chart-line'),
    VirtualTag.new('High Dividend Growth', '3Y or 5Y Dividend Growth ≥ 5.0%', ->(position) { position.stock.dividend_growth_3y.to_f >= 5.0 || position.stock.dividend_growth_5y.to_f >= 5.0 }, ->(_user) { XStocks::AR::Stock.where('dividend_growth_3y >= 5.0 or dividend_growth_5y >= 5.0') }, 'fa-chart-line'),
    VirtualTag.new('Safe Dividend', 'Dividend Safety ≥ 4.0', ->(position) { position.stock.dividend_rating && position.stock.dividend_rating >= 4.0 }, ->(_user) { XStocks::AR::Stock.where('dividend_rating >= 4.0') }, 'fa-shield-alt', '20-desc'),
    VirtualTag.new('High Score', 'Score > 60', ->(position) { position.stock.metascore && position.stock.metascore > 60 }, ->(_user) { XStocks::AR::Stock.where('metascore > 60') }, 'fa-shield-alt', '22-desc'),
    VirtualTag.new('S&P 500', 'S&P 500 Index', ->(position) { position.stock.sp500 }, ->(_user) { XStocks::AR::Stock.where(sp500: true) }, 'fa-list-ol'),
    VirtualTag.new('Nasdaq 100', 'Nasdaq 100 Index', ->(position) { position.stock.nasdaq100 }, ->(_user) { XStocks::AR::Stock.where(nasdaq100: true) }, 'fa-list-ol'),
    VirtualTag.new('Dow Jones', 'Dow Jones Industrial Average', ->(position) { position.stock.dowjones }, ->(_user) { XStocks::AR::Stock.where(dowjones: true) }, 'fa-list-ol'),
    VirtualTag.new('Ex Date Soon', 'Ex Date ≤ 1 month in the future', ->(position) { XStocks::Stock.new(position.stock).next_month_ex_date? }, ->(_user) { XStocks::AR::Stock.where(['next_div_ex_date > ? and next_div_ex_date <= ?', XStocks::Stock::Dividends.future_ex_date, XStocks::Stock::Dividends.next_month_ex_date]) }, 'fa-calendar-alt', '21-asc'),
    VirtualTag.new('My Note', 'My Note is Present', ->(position) { position.note.present? }, ->(user) { XStocks::AR::Position.where(user: user).pluck(:stock_id, :note).map { |stock_id, note| note.present? ? stock_id : nil }.compact }, 'fa-thumbtack')
  ].freeze
end
