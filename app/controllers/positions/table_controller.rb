# frozen_string_literal: true

module Positions
  # Table representation of user portfolio positions
  class TableController < ApplicationController
    memorize_params :datatable_positions, only: [:index] do
      params.permit(:items, columns: [])
    end

    def index
      positions = current_user.positions.joins(:stock).with_shares

      @table = table
      @table.sort { |column, direction| positions = positions.reorder(column => direction) }
      @table.filter { |query| positions = positions.where('LOWER(stocks.symbol) like LOWER(:query) or LOWER(stocks.company_name) like LOWER(:query)', query: "%#{query}%") }

      positions = positions.all
      positions = @table.paginate(positions)
      return unless stale?(positions)

      populate_data(positions)

      @page_title = t('positions.pages.portfolio')
      @page_menu_item = :positions
    end

    private

    def table
      table = DataTable::Table.new(params, DataTable::Table::DEFAULT_PAGINATION_OPTIONS + [['All', -1]], -1)

      table.init_columns do |columns|
        # Stock
        columns << DataTable::Column.new(code: 'smb', label: t('positions.columns.symbol'), formatter: 'stock_link', sorting: 'stocks.symbol', default: true)
        columns << DataTable::Column.new(code: 'cmp', label: t('positions.columns.company'), formatter: 'string', sorting: 'stocks.company_name', default: true)
        columns << DataTable::Column.new(code: 'cnt', label: t('positions.columns.country'), formatter: 'string', align: 'center', sorting: 'stocks.country')
        # Position
        columns << DataTable::Column.new(code: 'shr', label: t('positions.columns.shares'), formatter: 'number', sorting: 'positions.shares', default: true)
        columns << DataTable::Column.new(code: 'apr', label: t('positions.columns.average_price'), formatter: 'currency', sorting: 'positions.average_price', default: true)
        columns << DataTable::Column.new(code: 'mpr', label: t('positions.columns.market_price'), formatter: 'currency', sorting: 'positions.market_price', default: true)
        columns << DataTable::Column.new(code: 'cst', label: t('positions.columns.total_cost'), formatter: 'currency', sorting: 'positions.total_cost', default: true)
        columns << DataTable::Column.new(code: 'mvl', label: t('positions.columns.market_value'), formatter: 'currency', sorting: 'positions.market_value', default: true)
        columns << DataTable::Column.new(code: 'drc', label: t('positions.columns.today_return'), formatter: 'currency_delta')
        columns << DataTable::Column.new(code: 'drp', label: t('positions.columns.today_return_pct'), formatter: 'percent_delta2', sorting: 'stock.price_change_pct')
        columns << DataTable::Column.new(code: 'trc', label: t('positions.columns.today_return'), formatter: 'currency_delta', sorting: 'positions.gain_loss', default: true)
        columns << DataTable::Column.new(code: 'trp', label: t('positions.columns.today_return_pct'), formatter: 'percent_delta2', sorting: 'positions.gain_loss_pct', default: true)
        columns << DataTable::Column.new(code: 'ndv', label: t('positions.columns.next_div'), formatter: 'currency', default: true)
        columns << DataTable::Column.new(code: 'adv', label: t('positions.columns.annual_div'), formatter: 'currency', default: true)
        columns << DataTable::Column.new(code: 'dvr', label: t('positions.columns.diversity_pct'), formatter: 'percent2', sorting: 'positions.market_value')
        # Stop Loss
        columns << DataTable::Column.new(code: 'spp', label: t('positions.columns.stop_price'), formatter: 'currency')
        columns << DataTable::Column.new(code: 'ecr', label: t('positions.columns.est_credit'), formatter: 'currency')
        columns << DataTable::Column.new(code: 'ert', label: t('positions.columns.est_return'), formatter: 'currency_delta')
        columns << DataTable::Column.new(code: 'erp', label: t('positions.columns.est_return_pct'), formatter: 'percent_delta2')
        # Stock
        columns << DataTable::Column.new(code: 'prc', label: t('positions.columns.price'), formatter: 'currency')
        columns << DataTable::Column.new(code: 'prd', label: t('positions.columns.change'), formatter: 'currency_delta')
        columns << DataTable::Column.new(code: 'prp', label: t('positions.columns.change_pct'), formatter: 'percent_delta2')
        columns << DataTable::Column.new(code: 'wkr', label: t('positions.columns.52wk_range'), formatter: 'price_range')
        columns << DataTable::Column.new(code: 'frv', label: t('positions.columns.fair_value'), formatter: 'percent_delta0', sorting: 'stocks.yahoo_discount')
        columns << DataTable::Column.new(code: 'srg', label: t('positions.columns.short_term'), formatter: 'direction', sorting: 'stocks.yahoo_short_direction')
        columns << DataTable::Column.new(code: 'mrg', label: t('positions.columns.mid_term'), formatter: 'direction', sorting: 'stocks.yahoo_medium_direction')
        columns << DataTable::Column.new(code: 'lrg', label: t('positions.columns.long_term'), formatter: 'direction', sorting: 'stocks.yahoo_long_direction')
        columns << DataTable::Column.new(code: 'dvf', label: t('positions.columns.div_frequency'), formatter: 'string', sorting: 'stocks.dividend_frequency_num')
        columns << DataTable::Column.new(code: 'ead', label: t('positions.columns.est_annual_div'), formatter: 'currency_or_warning')
        columns << DataTable::Column.new(code: 'eyp', label: t('positions.columns.est_yield_pct'), formatter: 'percent_or_warning2')
        columns << DataTable::Column.new(code: 'dcp', label: t('positions.columns.div_change_pct'), formatter: 'percent_delta1')
        columns << DataTable::Column.new(code: 'per', label: t('positions.columns.pe_ratio'), formatter: 'number2', sorting: 'stocks.pe_ratio_ttm')
        columns << DataTable::Column.new(code: 'ptp', label: t('positions.columns.payout_pct'), formatter: 'percent2', sorting: 'stocks.payout_ratio')
        columns << DataTable::Column.new(code: 'yrc', label: t('positions.columns.yahoo_rec'), formatter: 'recommendation', sorting: 'stocks.yahoo_rec')
        columns << DataTable::Column.new(code: 'frc', label: t('positions.columns.finnhub_rec'), formatter: 'recommendation', sorting: 'stocks.finnhub_rec')
        columns << DataTable::Column.new(code: 'dsf', label: t('positions.columns.div_safety'), formatter: 'safety_badge', sorting: 'stocks.dividend_rating')
        columns << DataTable::Column.new(code: 'exd', label: t('positions.columns.ex_date'), formatter: 'future_date', sorting: 'stocks.next_div_ex_date')
      end
    end

    def populate_data(positions)
      positions = positions.to_a
      stocks = XStocks::Stock.find_all(id: positions.map(&:stock_id))
      @stocks_by_id = stocks.index_by(&:id)

      total_market_value = positions.sum(&:market_value)
      avg_dividend_rating = XStocks::Position::AvgDividendRating.new

      positions.each do |position|
        stock = @stocks_by_id[position.stock_id]
        div_suspended = stock.div_suspended?
        avg_dividend_rating.add(stock.dividend_rating, div_suspended, position.market_value)

        @table.rows << row(stock, position, div_suspended, total_market_value)
      end

      summary = { dividend_rating: avg_dividend_rating.value }
      summary = summary(@stocks_by_id, positions, summary)

      @table.footers << footer(summary)
    end

    def row(stock, position, div_suspended, total_market_value)
      diversity = position.market_value && total_market_value ? (position.market_value / total_market_value * 100).round(2) : nil
      flag = CountryFlag.new

      [
        # Stock
        stock.symbol,
        stock.company_name,
        flag.code(stock.country),
        # Position
        position.shares&.to_f,
        position.average_price&.to_f,
        position.market_price&.to_f,
        position.total_cost&.to_f,
        position.market_value&.to_f,
        stock.price_change && position.shares ? (stock.price_change * position.shares).to_f : nil,
        stock.price_change_pct&.to_f,
        position.gain_loss&.to_f,
        position.gain_loss_pct&.to_f,
        position.shares && stock.next_div_amount ? (position.shares * stock.next_div_amount)&.to_f : nil,
        position.est_annual_income&.to_f,
        diversity&.to_f,
        # Stop Loss
        position.stop_loss&.to_f,
        position.stop_loss_value&.to_f,
        position.stop_loss_gain_loss&.to_f,
        position.stop_loss_gain_loss_pct&.to_f,
        # Stock
        stock.current_price&.to_f,
        stock.price_change&.to_f,
        stock.price_change_pct&.to_f,
        stock.price_range,
        stock.yahoo_discount&.to_f,
        stock.yahoo_short_direction,
        stock.yahoo_medium_direction,
        stock.yahoo_long_direction,
        stock.dividend_frequency&.titleize,
        value_or_warning(div_suspended, stock.est_annual_dividend&.to_f),
        value_or_warning(div_suspended, stock.est_annual_dividend_pct&.to_f),
        stock.div_change_pct&.round(1),
        stock.pe_ratio_ttm&.to_f&.round(2),
        stock.payout_ratio&.to_f,
        stock.yahoo_rec&.to_f,
        stock.finnhub_rec&.to_f,
        stock.dividend_rating&.to_f,
        stock.prev_month_ex_date? ? stock.next_div_ex_date : nil,
        [stock.metascore, stock.meta_score_details]
      ]
    end

    def footer(summary)
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        summary.fetch(:total_cost),
        summary.fetch(:market_value),
        summary.fetch(:today_return),
        summary.fetch(:today_return_pct),
        summary.fetch(:total_return),
        summary.fetch(:total_return_pct),
        summary.fetch(:next_div),
        summary.fetch(:est_annual_div),
        100,
        nil,
        summary.fetch(:stop_loss_value),
        summary.fetch(:stop_loss_gain_loss),
        summary.fetch(:stop_loss_gain_loss_pct),
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        summary.fetch(:yield_on_value),
        nil,
        nil,
        nil,
        nil,
        nil,
        summary.fetch(:dividend_rating),
        nil,
        nil
      ]
    end

    def value_or_warning(div_suspended, value)
      div_suspended ? 'Sus.' : value
    end

    def summary(stocks_by_id, positions, summary)
      total_cost = positions.map(&:total_cost).compact.sum || 0
      market_value = positions.map(&:market_value).compact.sum || 0

      today_return = positions.sum do |position|
        stock = stocks_by_id[position.stock_id]
        position.shares && stock&.price_change ? position.shares * stock.price_change : 0
      end

      today_return_pct = total_cost.positive? ? today_return / market_value * 100 : 0
      total_return = market_value - total_cost
      total_return_pct = total_cost.positive? ? total_return / total_cost * 100 : 0

      next_div = positions.sum do |position|
        stock = stocks_by_id[position.stock_id]
        position.shares && stock&.next_div_amount ? position.shares * stock.next_div_amount : 0
      end

      est_annual_div = positions.map(&:est_annual_income).compact.sum
      yield_on_value = market_value.positive? ? (est_annual_div / market_value) * 100 : 0

      stop_loss_positions = positions.select(&:stop_loss_value)
      stop_loss_value = stop_loss_positions.sum(&:stop_loss_value) || 0
      stop_loss_gain_loss = stop_loss_positions.sum(&:stop_loss_gain_loss) || 0
      stop_loss_market_value = stop_loss_positions.sum(&:market_value) || 0
      stop_loss_gain_loss_pct = stop_loss_market_value.positive? ? (stop_loss_gain_loss / stop_loss_market_value) * 100 : 0

      summary.merge({
                      total_cost: total_cost,
                      market_value: market_value,
                      today_return: today_return,
                      today_return_pct: today_return_pct,
                      total_return: total_return,
                      total_return_pct: total_return_pct,
                      next_div: next_div,
                      est_annual_div: est_annual_div,
                      yield_on_value: yield_on_value,
                      stop_loss_value: stop_loss_value,
                      stop_loss_gain_loss: stop_loss_gain_loss,
                      stop_loss_gain_loss_pct: stop_loss_gain_loss_pct
                    })
    end
  end
end
