# frozen_string_literal: true

# Controller to provide stock information
class StocksController < ApplicationController
  include StocksHelper

  def index
    return if handle_goto_param?

    stock_ids = handle_tag_param

    stocks = XStocks::AR::Stock
    stocks = stocks.where(id: stock_ids) if @tag
    stocks = stocks.all.to_a

    @columns = columns
    @data = data(stocks)

    @page_title = 'Stocks'
    @page_menu_item = :stocks
  end

  def show
    @stock = find_stock
    not_found && return unless @stock

    begin
      Etl::Refresh::Finnhub.new.hourly_one_stock!(@stock)
    rescue StandardError
      nil
    end
    @position = XStocks::AR::Position.find_or_initialize_by(stock: @stock, user: current_user)

    set_page_title
  end

  def new
    @stock = XStocks::AR::Stock.new
    set_page_title
  end

  def create
    @stock = XStocks::AR::Stock.new(stock_params)

    if XStocks::Stock.new.save(@stock)
      XStocks::Service.new.lock(:company_information, force: true) do |logger|
        logger.text_size_limit = nil
        Etl::Refresh::Company.new.one_stock!(@stock, logger: logger)
      end

      redirect_to stock_path(@stock)
    else
      set_page_title
      render action: 'new'
    end
  end

  def destroy
    @stock = find_stock
    not_found && return unless @stock

    if XStocks::Stock.new.destroyable?(@stock)
      @stock.destroy
      flash[:notice] = "#{XStocks::Stock.new.to_s(@stock)} stock deleted"
      redirect_to stocks_path
    else
      redirect_to stock_path(@stock)
    end
  end

  private

  def set_page_title
    @page_title = @stock.new_record? ? 'New Stock' : XStocks::Stock.new.to_s(@stock)
    @page_menu_item = :stocks
  end

  def find_stock
    XStocks::AR::Stock.find_by(symbol: params[:id])
  end

  def stock_params
    params.require(:x_stocks_ar_stock).permit(:symbol)
  end

  def handle_goto_param?
    value = params[:goto]
    return false if value.blank?

    stock = XStocks::AR::Stock.find_by(symbol: value.upcase)
    if stock
      redirect_to stock_path(stock)
      return true
    end

    stocks = XStocks::AR::Stock.where('company_name ILIKE ?', "%#{value.downcase}%").all
    if stocks.count == 1
      redirect_to stock_path(stocks.first)
      return true
    end

    redirect_to url_for(search: value)
    true
  end

  def handle_tag_param
    @tag = params[:tag]
    return if @tag.blank?

    virtual_tag = VirtualTag.find(@tag)

    stock_ids =
      if virtual_tag
        virtual_tag.find_stock_ids(current_user)
      else
        XStocks::AR::Tag.where(name: @tag).pluck(:stock_id)
      end

    @tag = nil if stock_ids.blank? && !virtual_tag
    stock_ids
  end

  def columns
    columns = []

    columns << { label: 'Company', align: 'left', searchable: true, default: true }
    columns << { label: 'Price', default: true }
    columns << { label: 'Change', default: true }
    columns << { label: 'Change %', default: true }
    columns << { label: 'Fair Value', default: true }
    columns << { label: 'Est. Annual Div.', default: true }
    columns << { label: 'Est. Yield %', default: true }
    columns << { label: 'Div. Change %' }
    columns << { label: 'P/E Ratio' }
    columns << { label: 'Payout %' }
    columns << { label: 'Yahoo Rec.', default: true }
    columns << { label: 'Finnhub Rec.', default: true }
    columns << { label: 'Div. Safety', default: true }
    columns << { label: 'Ex Date' }
    columns << { label: 'Score', align: 'center', default: true }

    columns.each_with_index { |column, index| column[:index] = index + 1 }
    columns
  end

  def data(stocks)
    model = XStocks::Stock.new

    positions = XStocks::AR::Position.where(stock: stocks, user: current_user).all
    positions = positions.index_by(&:stock_id)

    stocks.map do |stock|
      position = positions[stock.id]
      div_suspended = model.div_suspended?(stock)
      [
        [stock.symbol, stock.logo, position&.note.presence],
        stock.company_name,
        stock.current_price&.to_f,
        stock.price_change&.to_f,
        stock.price_change_pct&.to_f,
        stock.yahoo_discount&.to_f,
        value_or_warning(div_suspended, stock.est_annual_dividend&.to_f),
        value_or_warning(div_suspended, stock.est_annual_dividend_pct&.to_f),
        model.div_change_pct(stock)&.round(1),
        stock.pe_ratio_ttm&.to_f&.round(2),
        stock.payout_ratio&.to_f,
        stock.yahoo_rec&.to_f,
        stock.finnhub_rec&.to_f,
        stock.dividend_rating&.to_f,
        stock.next_div_ex_date && !stock.next_div_ex_date.past? ? stock.next_div_ex_date : nil,
        [stock.metascore, model.metascore_details(stock)]
      ]
    end
  end

  def value_or_warning(div_suspended, value)
    div_suspended ? 'Sus.' : value
  end
end
