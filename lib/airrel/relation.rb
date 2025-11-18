# frozen_string_literal: true

module Airrel
  class Relation
    include Enumerable

    attr_reader :klass, :where_clause, :order_values, :limit_value, :offset_value

    def initialize(klass)
      @klass = klass
      @where_clause = WhereClause.new
      @order_values = []
      @limit_value = nil
      @offset_value = nil
      @loaded = false
      @records = nil
    end

    # chaining methods (return new relations)

    def where(conditions) = spawn.where!(conditions)

    def where!(conditions)
      @where_clause = @where_clause.merge(conditions)
      self
    end

    def order(*args) = spawn.order!(*args)

    def order!(*args)
      @order_values += parse_order_args(args)
      self
    end

    def limit(value) = spawn.limit!(value)

    def limit!(value)
      @limit_value = value
      self
    end

    def offset(value) = spawn.offset!(value)

    def offset!(value)
      @offset_value = value
      self
    end

    def reorder(*args) = spawn.reorder!(*args)

    def reorder!(*args)
      @order_values = parse_order_args(args)
      self
    end

    # finder methods (execute queries)

    def first(limit = nil)
      if limit
        # explicitly set limit to avoid loading more than needed
        self.limit(limit).to_a
      else
        # only load 1 record
        self.limit(1).to_a.first
      end
    end

    def last(limit = nil)
      # if no order specified, airtable returns oldest first by default
      # so we need to explicitly reverse or it's meaningless
      if @order_values.empty?
        raise ArgumentError, "last requires an order to be specified (use .order(:created_at) or similar)"
      end

      reversed = reverse_order
      if limit
        # only load what we need
        reversed.limit(limit).to_a.reverse
      else
        # only load 1 record
        reversed.limit(1).to_a.first
      end
    end

    def find(id) = klass.find(id)

    def find_by(conditions) = where(conditions).first

    def find_by!(conditions)
      # Raise error class that will be defined by the consumer (norairrecord)
      error_class = defined?(Norairrecord::RecordNotFoundError) ? Norairrecord::RecordNotFoundError : StandardError
      find_by(conditions) || raise(error_class, "Record not found")
    end

    def all = spawn

    def to_a = load_records

    alias to_ary to_a

    def each(&block) = load_records.each(&block)

    # batch iteration for large result sets
    def find_each(batch_size: 100, &block)
      find_in_batches(batch_size: batch_size) do |batch|
        batch.each(&block)
      end
    end

    def find_in_batches(batch_size: 100)
      current_offset = 0

      loop do
        # create a new relation with limit and offset
        batch_relation = spawn
        batch_relation.instance_variable_set(:@limit_value, batch_size)
        batch_relation.instance_variable_set(:@offset_value, current_offset)

        batch = batch_relation.to_a
        break if batch.empty?

        yield batch

        break if batch.size < batch_size # last batch

        current_offset += batch_size
      end
    end

    # airtable doesn't have a count API >:-/ we gotta paginate through EVERYTHING...
    def count = load_records.size

    def empty? = !any?

    # OPTIMIZE: only load 1 record to check existence
    def any? = limit(1).load_records.any?

    def exists? = any?

    # inspection

    def inspect
      entries = load_records.take(11).map!(&:inspect)
      entries[10] = "..." if entries.size == 11

      "#<#{self.class.name} [#{entries.join(", ")}]>"
    end

    def to_airtable = to_airtable_params

    def to_sql = to_airtable_params.inspect

    # execution

    def load
      @records = exec_queries unless loaded?
      self
    end

    def reload
      reset
      load
    end

    def loaded? = @loaded

    def reset
      @loaded = false
      @records = nil
      self
    end

    # disable automatic pagination for better control
    def without_pagination
      @paginate = false
      self
    end

    protected

    def spawn = clone.tap(&:reset)

    def load_records
      load unless loaded?
      @records
    end

    def exec_queries
      @loaded = true
      params = to_airtable_params
      klass.records(**params)
    end

    def to_airtable_params
      params = {}

      # filter
      params[:filter] = @where_clause.to_airtable_formula if @where_clause.any?

      # sort
      if @order_values.any?
        params[:sort] = @order_values.map do |field, direction|
          { field: field.to_s, direction: direction.to_s }
        end
      end

      # limit
      params[:max_records] = @limit_value if @limit_value

      # offset (airtable calls it offset in pagination)
      params[:offset] = @offset_value if @offset_value

      # pagination control
      params[:paginate] = @paginate if defined?(@paginate)

      params
    end

    def reverse_order
      spawn.tap do |r|
        r.instance_variable_set(:@order_values, @order_values.map { |f, d| [f, d == :asc ? :desc : :asc] })
      end
    end

    def parse_order_args(args)
      args.flat_map do |arg|
        case arg
        when Hash
          arg.map { |k, v| [k, normalize_direction(v)] }
        when Symbol, String
          [[arg, :asc]]
        else
          raise ArgumentError, "Invalid order argument: #{arg.inspect}"
        end
      end
    end

    def normalize_direction(direction)
      case direction.to_s.downcase
      when "asc", "ascending"
        :asc
      when "desc", "descending"
        :desc
      else
        raise ArgumentError, "Invalid sort direction: #{direction}"
      end
    end
  end
end
