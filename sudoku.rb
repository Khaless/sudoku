require 'set'

# a Sudoku Grid
# Holds the actual data values
class Grid

	CELL_RANGE = (0...9*9)
	ROW_RANGE = (0...9)
	COLUMN_RANGE = (0...9)
	BOX_RANGES = [[0..2, 0..2], [0..2, 3..5], [0..2, 6..8], 
				  [3..5, 0..2], [3..5, 3..5], [3..5, 6..8], 
				  [6..8, 0..2], [6..8, 3..5], [6..8, 6..8]]

	attr_reader :cells, :rows, :columns, :boxes

	def initialize
		@cells = CELL_RANGE.map { |idx| Cell.new(*idx_to_xy(idx)) }
		@rows = ROW_RANGE.map { |row| Row.new(@cells.select { |cell| cell.x == row }) }
		@columns = COLUMN_RANGE.map { |column| Column.new(@cells.select { |cell| cell.y == column }) }
		@boxes = BOX_RANGES.map { |v|
					Box.new(v, @cells.select { |cell|
						v[0] === cell.x and v[1] === cell.y
					})
				 }
	end

	def cell_at(x, y)
		@cells[xy_to_idx(x, y)]
	end
	
	def row(y)
		@rows[y]
	end

	def column(x)
		@columns[x]
	end

	def box_for(x, y) 
		@boxes.select { |box| box.x_range === x and box.y_range === y }.first
	end

	# From any cell in this cells row/col/box, remove the cell's
	# value from the possible list
	def adjust_possibles(cell) 
		row(cell.x).cells.each { |c|
			c.remove_possible(cell.value)
		}
		column(cell.y).cells.each { |c|
			c.remove_possible(cell.value)
		}
		box_for(cell.x, cell.y).cells.each { |c|
			c.remove_possible(cell.value)
		}
	end

	def pretty_print
		row_sep = '++---+---+---++---+---+---++---+---+---++'
		row = -1
		@cells.each { |cell|
			if row != cell.x
				printf("\n%s\n", (cell.x % 3 == 0) ? row_sep.gsub(/-/, '=') : row_sep)
				printf '||'
				row = cell.x
			end
			printf(' %s %s', cell.value.nil? ? ' ' : cell.value.to_s, (cell.y % 3 == 2) ? '||' : '|')
		}
		printf("\n%s\n\n", row_sep.gsub(/-/, '='))
	end

	def xy_to_idx(x, y)
		x * 9 + y
	end

	def idx_to_xy(idx)
		[(idx / 9), (idx % 9)]
	end

end

# a single Cell
class Cell

	attr_reader :x, :y, :possible, :value

	def initialize(*args)
		@value = nil
		@possible = Set.new

		@x = args[0]
		@y = args[1]
	end

	def value=(val)
		@value = val
		@possible = Set.new 
	end

	def clear_possible
		@possible = Set.new 
	end

	def add_possible(val)
		@possible << val
	end

	def remove_possible(val)
		@possible.delete(val)
	end

	# Useful if we want to test a case by creating a sample grid 
	# with sample possible values.
	def debug_possible(vals)
		@possible = Set.new(vals)
	end

end

module CellCollection
	def include?(val)
		@cells.select { |cell| cell.value == val }.length > 0
	end
	def possible_cells_for(val)
		@cells.select { |cell| cell.possible.include?(val) }
	end
end

# a 3x3 Cell Box
class Box
	attr_reader :x_range, :y_range, :cells
	include CellCollection
	def initialize(*args)
		@x_range = args[0][0]
		@y_range = args[0][1]
		@cells = args[1]
	end
end

# a 1x9 Row
class Row
	attr_accessor :cells
	include CellCollection
	def initialize(cells)
		@cells = cells
	end
end

# a 1x9 Column
class Column
	attr_accessor :cells
	include CellCollection
	def initialize(cells)
		@cells = cells
	end
end

class Solver
	def initialize(grid)
		@grid = grid
	end

	def solve

		initialize_possibles

		values_set, last = -1, 0
		while values_set != last
			last = values_set

			# Possible Removers
			naked_pairs
			
			# Value Setters
			hidden_singles
			singles

			values_set = @grid.cells.select { |c| !c.value.nil? }.length
		end
	end

	def initialize_possibles

		@grid.cells.each { |cell|
			if cell.value.nil?
				(1..9).each { |val|
					if !@grid.row(cell.x).include?(val) \
						and !@grid.column(cell.y).include?(val) \
						and !@grid.box_for(cell.x, cell.y).include?(val)
						cell.add_possible(val)
					end
				}
			end
		}
	end
	
	# assign a value to a cell with only 1 possible
	def singles
		@grid.cells.each { |cell|
			if cell.possible.length == 1
				#p "found a single"
				cell.value = cell.possible.to_a.first
				@grid.adjust_possibles(cell)
			end
		}
	end

	# assign a value if a box, row or column only has 1 possible for a value
	def hidden_singles
		fn = lambda { |collection|
			(1..9).map { |val| {:val => val, :cells => collection.possible_cells_for(val)} }.select { |hash| hash[:cells].length == 1}.each { |v|
				v[:cells].each { |cell|
					#p "found a hidden signal"
					cell.value = v[:val]
					@grid.adjust_possibles(cell)
				}
			}
		}
		@grid.rows.each(&fn)
		@grid.columns.each(&fn)
		@grid.boxes.each(&fn)
	end

	def naked_pairs
		fn = lambda { |collection|
			pairs = Set.new
			collection.cells.each { |cell|
				if cell.possible.length == 2
					collection.cells.each { |cell2|
						# If they contain the same 2 candidates
						if cell.possible == cell2.possible and !cell.equal?(cell2)
							#p "Found a naked pair"
							pairs << cell.possible
						end
					} 
				end
			}
			pairs.each { |pair|
				collection.cells.each { |cell|
					if pair != cell.possible
						pair.each { |v|
							cell.remove_possible(v)
						}
					end
				}
			}
		}
		@grid.rows.each(&fn)
		@grid.columns.each(&fn)
		@grid.boxes.each(&fn)
	end

end

g = Grid.new

g.cell_at(1,2).value = 7
g.cell_at(1,3).value = 8
g.cell_at(1,4).value = 3
g.cell_at(1,6).value = 9

g.cell_at(2,2).value = 5
g.cell_at(2,5).value = 2
g.cell_at(2,6).value = 6
g.cell_at(2,7).value = 4

g.cell_at(3,2).value = 2
g.cell_at(3,3).value = 6
g.cell_at(3,7).value = 7

g.cell_at(4,1).value = 4
g.cell_at(4,7).value = 8

g.cell_at(5,1).value = 6
g.cell_at(5,5).value = 3
g.cell_at(5,6).value = 2

g.cell_at(6,1).value = 2
g.cell_at(6,2).value = 8
g.cell_at(6,3).value = 4
g.cell_at(6,6).value = 5

g.cell_at(7,4).value = 9
g.cell_at(7,5).value = 6
g.cell_at(7,6).value = 1

=begin
# Should find a 9 in 0,0 through single
g.cell_at(1,0).value = 1
g.cell_at(2,0).value = 2
g.cell_at(3,0).value = 3
g.cell_at(4,0).value = 4
g.cell_at(5,0).value = 5
g.cell_at(6,0).value = 6
g.cell_at(7,0).value = 7
g.cell_at(8,0).value = 8
=end

=begin
g.cell_at(1,3).value = 1
g.cell_at(2,6).value = 1
g.cell_at(3,1).value = 1
g.cell_at(6,2).value = 1
=end

=begin
# Values, then possibles
g.cell_at(0,0).value = 7
g.cell_at(0,4).value = 9
g.cell_at(0,8).value = 3

g.cell_at(0,1).debug_possible([1,2,4,5])
g.cell_at(0,2).debug_possible([1,4,5])
g.cell_at(0,3).debug_possible([2,4,5])
g.cell_at(0,5).debug_possible([8,6])
g.cell_at(0,6).debug_possible([8,6])
g.cell_at(0,7).debug_possible([1,6,8])
=end

print "=======================\n"
print " Beginning With"
print "=======================\n"
g.pretty_print

s = Solver.new(g)
s.solve

print "=======================\n"
print " Ending With\n"
print "=======================\n"
g.pretty_print

