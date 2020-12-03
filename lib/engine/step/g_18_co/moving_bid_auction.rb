# frozen_string_literal: true

require_relative '../base'
require_relative '../auctioner'

module Engine
  module Step
    module G18CO
      class MovingBidAuction < Base
        include Auctioner
        ACTIONS = %w[bid move_bid pass].freeze

        attr_reader :companies

        def description
          'Moving Bid Auction for Companies'
        end

        def available
          @companies
        end

        def process_pass(action)
          entity = action.entity
          @log << "#{entity.name} passes bidding"
          entity.pass!
          all_passed! if entities.all?(&:passed?)
          @round.next_entity_index!
        end

        def process_bid(action)
          add_bid(action)
          action.entity.unpass!
          @round.next_entity_index!
        end

        def process_move_bid(action)
          move_bid(action)
          action.entity.unpass!
          @round.next_entity_index!
        end

        def actions(_entity)
          return [] if entities.all?(&:passed?)

          ACTIONS
        end

        def setup
          setup_auction
          @companies = @game.companies.sort_by(&:value)
        end

        def round_state
          {
            companies_pending_par: [],
          }
        end

        def auctioning
          nil
        end

        # min bid is face value or $5 higher than previous bid
        def min_bid(company)
          return unless company

          high_bid = highest_bid(company)
          (high_bid ? high_bid.price + min_increment : company.min_bid)
        end

        # can never purchase directly
        def may_purchase?(_company)
          false
        end

        def committed_cash(player, _show_hidden = false)
          bids = bids_for_player(player)
          return 0 if bids.empty?

          bids.sum(&:price)
        end

        def current_bid_amount(player, company)
          @bids[company]&.select { |b| b.entity == player }&.sort(&:price)&.last&.price || 0
        end

        def max_bid(player, company)
          player.cash - committed_cash(player) + current_bid_amount(player, company)
        end

        def moveable_bids(player, company)
          @bids.map do |cmp, company_bids|
            next if cmp == company

            player_bids = company_bids.select { |bid| bid.entity == player }
            next if player_bids.empty?

            [cmp, player_bids]
          end.compact.to_h
        end

        protected

        # every company is always up for auction
        def can_auction?(_company)
          true
        end

        def all_passed!
          @bids.each do |company, bids|
            resolve_bids_for_company(company, bids)
          end
        end

        def resolve_bids_for_company(company, bids)
          return if bids.empty?

          # Companies without bids can be bought be corporations later
          # Unsure how that will be accomplished at this time
          high_bid = highest_bid(company)
          buy_company(high_bid.entity, company, high_bid.price)
        end

        def buy_company(player, company, price)
          company.owner = player
          player.companies << company
          player.spend(price, @game.bank) if price.positive?
          @companies.delete(company)

          @log << "#{player.name} wins the auction for #{company.name} "\
                  "with #{@bids[company].size > 1 ? 'a' : 'the only'} "\
                  "bid of #{@game.format_currency(price)}"

          company.abilities(:shares) do |ability|
            ability.shares.each do |share|
              if share.president
                @round.companies_pending_par << company
              else
                @game.share_pool.buy_shares(player, share, exchange: :free)
              end
            end
          end
        end

        def accept_bid(bid)
          price = bid.price
          company = bid.company
          player = bid.entity
          @bids.delete(company)
          buy_company(player, company, price)
        end

        def add_bid(bid)
          company = bid.company || bid.corporation
          entity = bid.entity
          price = bid.price
          min = min_bid(company)

          @game.game_error("Minimum bid is #{@game.format_currency(min)} for #{company.name}") if price < min
          if @game.class::MUST_BID_INCREMENT_MULTIPLE && ((price - min) % min_increment).nonzero?
            @game.game_error("Must increase bid by a multiple of #{@game.format_currency(min_increment)}")
          end
          if price > max_bid(entity, company)
            @game.game_error("Cannot afford bid. Maximum possible bid is
              #{@game.format_currency(max_bid(entity, company))}")
          end

          bids = @bids[company]
          highest_player_bid = bids.sort(&:price).reverse.find { |b| b.entity == entity }
          bids.delete(highest_player_bid) if highest_player_bid
          bids << bid

          @log << "#{entity.name} bids #{@game.format_currency(price)} for #{bid.company.name}"
        end

        def move_bid(bid)
          entity = bid.entity
          company = bid.company
          old_company = bid.old_company
          price = bid.price
          old_price = bid.old_price
          min = min_bid(company)

          @game.game_error("Minimum bid is #{@game.format_currency(min)} for #{company.name}") if price < min
          if @game.class::MUST_BID_INCREMENT_MULTIPLE && ((price - min) % min_increment).nonzero?
            @game.game_error("Must increase bid by a multiple of #{@game.format_currency(min_increment)}")
          end
          if price > max_bid(entity, company)
            @game.game_error("Cannot afford bid. Maximum possible bid is
              #{@game.format_currency(max_bid(entity, company))}")
          end
          if price < (old_price + min_increment)
            @game.game_error("Bid movement must increase original bid by a multiple of
              #{@game.format_currency(min_increment)}")
          end

          @bids[old_company].reject! { |b| b.entity == entity && b.price == old_price }

          bids = @bids[company]
          bids << bid

          @log << "#{entity.name} moves #{@game.format_currency(old_price)} bid from
            #{old_company.name} to bid #{@game.format_currency(price)} for #{bid.company.name}"
        end

        def bids_for_player(player)
          @bids.values.map do |bids|
            bids.select { |bid| bid.entity == player }
          end.flatten.compact
        end
      end
    end
  end
end
