require 'semantic'

module DataTester
  class Filters
    IN = 'in'
    NOT_IN = 'ni'
    EQ = '=='
    NEQ = '!='

    GT = '>'
    GE = '>='
    LT = '<'
    LE = '<='

    INTEGER = ['int', 'number']
    STRING = ['string']
    BOOLEAN = ['boolean', 'bool']

    OR = '||'
    AND = '&&'

    def statisfied?(rules, data)
      final_result = true

      return final_result if rules.nil?

      rules.each_with_index do |rule, index|
        result = false

        if rule.include?('conditions')
          result = statisfied?(rule['conditions'], data)
        elsif rule.include?('condition')
          result = statisfied_condition?(rule['condition'], data)
        end

        if index.zero?
          final_result = result
          next
        end

        if rule['logic'] == OR
          final_result ||= result
        elsif rule['logic'] == AND
          final_result &&= result
        end
      end

      final_result
    end

    def statisfied_condition?(rule, data)
      operator = rule['op']

      return false if !rule.fetch('key', nil) || !data.include?(rule['key'])

      value = data[rule['key']]
      target = rule['value']
      method = rule['method']

      statisfied, value = type_statisfied(rule['type'], value)
      return false unless statisfied

      value_compare(value, target, operator, method)
    end

    def type_statisfied(type, value)
      case type
      when *STRING
        return [value.is_a?(String), value]
      when *INTEGER
        return [value.is_a?(Integer) || value.is_a?(Float), value]
      when *BOOLEAN
        return [value.is_a?(TrueClass) || value.is_a?(FalseClass), value]
      end
      [false, value]
    end

    def value_compare(value, target, operator, method)
      actions = {
        EQ => value == target,
        NEQ => value != target,
        IN => target.is_a?(Array) && target.include?(value),
        NOT_IN => target.is_a?(Array) && !target.include?(value)
      }
      return actions[operator] if actions.include?(operator)

      method == 'version' ? version_value_compare(value, target, operator) : dict_value_compare(value, target, operator)
    end

    def version_value_compare(value, target, operator)
      version_value = Semantic::Version.new value
      version_target = Semantic::Version.new target
      dict_value_compare(version_value, version_target, operator)
    end

    def dict_value_compare(value, target, operator)
      actions = {
        GT => value > target,
        GE => value >= target,
        LT => value < target,
        LE => value <= target
      }
      actions.include?(operator) ? actions[operator] : false
    end
  end
end
