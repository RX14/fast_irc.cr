module FastIRC
  # :nodoc:
  module ParserHelpers
    macro incr
      pos += 1
      cur = str[pos]
    end

    macro read_until(*chars)
      {% expressions = [] of String %}
      {% for char in chars %}
        {% expressions += ["cur != " + char.stringify + ".ord"] %}
      {% end %}
      {% expressions += ["cur != 0"] %}

      while {{expressions.join(" && ").id}}
        incr
      end
    end

    macro parse_field
      %start = pos
      {{yield}}
      %length = pos - %start

      String.new str[%start, %length]
    end
  end
end
