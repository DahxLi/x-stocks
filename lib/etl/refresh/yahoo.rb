module Etl
  module Refresh
    class Yahoo

      def daily_last_run_at
        DateTime.parse(Config[:daily_yahoo_updated_at]) rescue nil
      end

      def daily_all_stocks?
        updated_at = daily_last_run_at
        updated_at.nil? || updated_at < 1.day.ago
      end

      def daily_all_stocks!
        Stock.all.each do |stock|
          daily_one_stock!(stock)
          sleep(1.0) # Limit up to 1 request per second
        end
        Config[:daily_yahoo_updated_at] = DateTime.now
      end

      def daily_all_stocks
        daily_all_stocks! if daily_all_stocks?
      end

      def daily_one_stock!(stock)
        json = Etl::Extract::Yahoo.new.statistics(stock.symbol)
        Etl::Transform::Yahoo::new.statistics(stock, json)
      end

    end
  end
end
