require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @column if @column
    cols = DBConnection.execute2(<<-SQL).first
    SELECT
    *
    FROM
      "#{self.table_name}"
    LIMIT 0
  SQL
  cols.map!(&:to_sym)
    @column = cols
  end

  def self.finalize!
    self.columns.each do |col|
      define_method(col) do
        self.attributes[col]
      end
      define_method("#{col}=") do |arg|
        self.attributes[col] = arg
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.underscore.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        "#{table_name}".*
      FROM
      "#{table_name}"
    SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
    
  end

  def self.find(id)
    self.all.find { |obj| obj.id == id }
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      if self.class.columns.include?(attr_name)
        self.send("#{attr_name}=", value)
      else
        raise "unknown attribute '#{attr_name}'"
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |atr| self.send(atr.to_sym) }
  end

  def insert
    cols = self.class.columns.drop(1)
    other_col = cols.map(&:to_sym).join(',')
    question = (['?'] * cols.count).join(',')
    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
    INSERT INTO
    #{self.class.table_name} (#{other_col}) 
    VALUES
    (#{question})
    
    SQL
    
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set = self.class.columns.map{ |attr_name| "#{attr_name} = ?"}.join(',')
    DBConnection.execute(<<-SQL, *attribute_values, id)
    UPDATE
      #{self.class.table_name}
    SET
      #{set}
    WHERE
      #{self.class.table_name}.id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
