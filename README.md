# Airrel

arel-like relational algebra for airtable. it's like arel but AIR. get it?

chainable queries that don't execute until you iterate. builds airtable formulas for you.

## installation

```ruby
gem 'airrel'
```

## usage

```ruby
require 'airrel'
require 'norairrecord'

class User < Norairrecord::Table
  self.base_key = "appXXX"
  self.table_name = "Users"
  
  # add the relation magic
  def self.all
    Airrel::Relation.new(self)
  end
end

# now you can chain!
User.all.where(role: "admin").where(active: true).order(created_at: :desc).limit(10)

# queries are lazy - nothing executes until you iterate
users = User.all.where(role: "admin") # no API call yet
users.each { |u| puts u["Name"] }     # now it executes

# all the usual suspects
User.all.where(age: 18..65)           # range queries
User.all.where(role: ["admin", "mod"]) # IN queries  
User.all.where(email: nil)            # BLANK() checks
User.all.order(:name)                 # sorting
User.all.order(name: :asc, age: :desc)
User.all.limit(10)
User.all.offset(20)

# finder methods
User.all.find_by(email: "test@example.com")
User.all.find_by!(email: "test@example.com") # raises if not found
User.all.first
User.all.first(5)
User.all.order(:created_at).last              # requires an order!
User.all.count

# raw formulas still work
User.all.where("{Age} > 18")
User.all.where("AND({Active} = TRUE(), {Role} = 'admin')")

# inspect the query without executing
User.all.where(role: "admin").to_airtable
# => {:filter=>"AND({role} = 'admin')"}
```

## formula builder

build complex airtable formulas programmatically:

```ruby
include Airrel::FormulaBuilder

# basic predicates
eq("Name", "Alice")           # => "{Name} = 'Alice'"
neq("Age", 25)                # => "NOT({Age} = 25)"
gt("Age", 18)                 # => "{Age} > 18"
gte("Age", 18)                # => "{Age} >= 18"
lt("Age", 65)                 # => "{Age} < 65"
lte("Age", 65)                # => "{Age} <= 65"

# boolean logic
all(eq("Role", "admin"), eq("Active", true))
any(eq("Role", "admin"), eq("Role", "moderator"))
none(blank("Email"))

# helpers
blank("Email")                # => "{Email} = BLANK()"
present("Email")              # => "NOT({Email} = BLANK())"
find("Name", "Alice")         # => "FIND('Alice', {Name})"
search("Tags", "important")   # => "SEARCH('important', {Tags})"

# use in queries
User.all.where(
  all(
    gte("Age", 18),
    present("Email")
  )
)
```

## how it works

`Airrel::Relation` is a lazy query builder. it:

1. stores query state (where clauses, ordering, limits)
2. doesn't execute until you iterate or call a terminal method
3. returns new relation objects when you chain (immutable)
4. converts everything to airtable API params when executed

hash conditions get converted to airtable formulas:
- `{ role: "admin" }` → `{role} = 'admin'`
- `{ age: nil }` → `{age} = BLANK()`
- `{ active: true }` → `{active} = TRUE()`
- `{ age: 18..65 }` → `AND({age} >= 18, {age} <= 65)`
- `{ role: ["admin", "mod"] }` → `OR({role} = 'admin', {role} = 'mod')`

multiple where clauses get AND'd together:
```ruby
User.all.where(role: "admin").where(active: true)
# => AND({role} = 'admin', {active} = TRUE())
```

## combining with field mappings

if you're using field mappings (like in airctiverecord), you can pass them to the formula builder:

```ruby
field_mappings = { first_name: "First Name", last_name: "Last Name" }

Airrel::FormulaBuilder.hash_to_formula(
  { first_name: "Alice" },
  field_mappings
)
# => "{First Name} = 'Alice'"
```

## security & escaping

**string escaping**

all string values are properly escaped for airtable formulas:
- single and double quotes are backslash-escaped: `O'Reilly` → `'O\'Reilly'`
- works for hash conditions, find/search helpers, and manual formula building

```ruby
User.where(name: "O'Reilly")
# => {filter: "{name} = 'O\'Reilly'"}

find("Name", "it's working")
# => "FIND('it\'s working', {Name})"
```

**field names**

field names are used as-is in `{fieldName}` syntax. if you're accepting user input for field names, validate them first - airtable field names can contain most characters but shouldn't contain `{` or `}`.

**injection safety**

because we properly escape all string values, formula injection attacks are prevented:

```ruby
User.where(name: "'; DROP TABLE users; --")
# => {filter: "{name} = '\'; DROP TABLE users; --'"}
# safe! airtable will look for a name with that exact string
```

## performance considerations

**automatic optimizations**

Airrel automatically optimizes common queries:

```ruby
User.first          # limit(1) - only loads 1 record
User.last           # limit(1) with reversed order
User.any?           # limit(1) - checks if at least 1 exists
User.empty?         # !any? - same optimization
User.first(10)      # limit(10) - only loads 10 records
```

**count is expensive**

airtable doesn't have a count API, so `count` loads all matching records:

```ruby
User.where(role: "admin").count  # loads ALL admin users!
```

if you just need to check existence, use `any?` or `exists?`:

```ruby
User.where(role: "admin").any?   # only loads 1 record ✓
```

**pagination**

by default, norairrecord paginates through all results. for large tables (25k+ records), consider:

```ruby
# process in batches
User.limit(100).offset(0).each { |u| process(u) }
User.limit(100).offset(100).each { |u| process(u) }

# or disable pagination for a single page
User.limit(100).without_pagination.to_a
```

**field selection**

norairrecord supports field selection to reduce payload size (though not exposed in Airrel yet).

## license

MIT
