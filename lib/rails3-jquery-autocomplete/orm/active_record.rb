module Rails3JQueryAutocomplete
  module Orm
    module ActiveRecord
      def get_autocomplete_order(method, term, options, model=nil)
        order = options[:order]

        table_prefix = model ? "#{model.table_name}." : ""
        if options[:similarity] and postgres?(model)
          order || "#{table_prefix}#{method} <-> '#{term}' ASC" # SQL Injection anyone? FIXME!
        else
          order || "#{table_prefix}#{method} ASC"
        end
      end

      def get_autocomplete_items(parameters)
        model   = parameters[:model]
        term    = parameters[:term]
        method  = parameters[:method]
        options = parameters[:options]
        scopes  = Array(options[:scopes])
        where   = options[:where]
        limit   = get_autocomplete_limit(options)
        order   = get_autocomplete_order(method, term, options, model)


        items = model.scoped

        scopes.each { |scope| items = items.send(scope) } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
        items = items.where(get_autocomplete_where_clause(model, term, method, options)).
            limit(limit).order(order)
        items = items.where(where) unless where.blank?

        items
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{table_name}.#{method}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options)
        table_name = model.table_name
        is_full_search = options[:full]
        is_similarity = options[:similarity]
        similarity_clause = '%'
        like_clause = (postgres?(model) ? 'ILIKE' : 'LIKE')

        query = "LOWER(#{table_name}.#{method}) #{like_clause} :liked_term"
        if is_similarity and postgres?(model)
          query += " OR LOWER(#{table_name}.#{method}) #{similarity_clause} :term"
        end

        [query, :liked_term => "#{is_full_search ? '%' : ''}#{term.downcase}%", :term => term]
      end

      def postgres?(model)
        # Figure out if this particular model uses the PostgreSQL adapter
        model.connection.class.to_s.match(/PostgreSQLAdapter/)
      end
    end
  end
end
