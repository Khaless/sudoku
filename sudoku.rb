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

	ROW_RANGE = (0...3)
	COLUMN_RANGE = (0...3)

	attr_reader :x_range, :y_range, :cells, :rows, :columns

	include CellCollection

	def initialize(*args)
		@x_range = args[0][0]
		@y_range = args[0][1]
		@cells = args[1]

		@rows = ROW_RANGE.map { |row| Row.new(@cells.select { |cell| row + @x_range.first == cell.x }) }
		@columns = COLUMN_RANGE.map { |column| Column.new(@cells.select { |cell| column + @y_range.first == cell.y }) }
		
	end

	# this operation works relative to the top of the box.
	# i.e. box 2 (top middle box) cell 0,0 is actually grid cell 0,3
	def cell_at(x, y)
		@cells.select { |cell| cell.x == @x_range.first + x and cell.y == @y_range.first + y }.first
	end

end

class Row
	attr_accessor :cells
	include CellCollection
	def initialize(cells)
		@cells = cells
	end

	# Returns a set of all the possible values which can 
	# occupy this row
	def possible
		@cells.inject(Set.new) { |row_set, cell|
			row_set.merge(cell.possible)
		}
	end

end
Column = Row # Column Class == Row Class

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
			locked_candidate_1
			
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

	def locked_candidate_1

		# for each column/row in a box, look for 
		# values which only appear in that col/row of the box.
		# we can then remove these values from every other cell 
		# in the row/col (out of the box)
		@grid.boxes.each { |box|
			# ROWS
			box.rows.each { |row|
				diff_set = row.possible
				box.rows.each { |row2|
					if !row.equal?(row2)
						diff_set = diff_set - row2.possible
					end
				}
				# Diff set contains a list of values in this box row which
				# are not in any other row in the box. we can remove them
				# from the cells in the row that are outside of the box
				@grid.row(row.cells.first.x).cells.each { |cell|
					if !row.cells.include?(cell)
						diff_set.each { |v|
							#p "Removing Locked Candidate"
							cell.remove_possible(v)
						}
					end
				}
			}
			# COLUMNS
			box.columns.each { |column|
				diff_set = column.possible
				box.columns.each { |column2|
					if !column.equal?(column2)
						diff_set = diff_set - column2.possible
					end
				}
				# Diff set contains a list of values in this box column which
				# are not in any other column in the box. we can remove them
				# from the cells in the column that are outside of the box
				@grid.column(column.cells.first.y).cells.each { |cell|
					if !column.cells.include?(cell)
						diff_set.each { |v|
							#p "Removing Locked Candidate"
							cell.remove_possible(v)
						}
					end
				}
			}
		}
	end
end

g = Grid.new

g.cell_at(0,1).value = 7
g.cell_at(0,6).value = 8

g.cell_at(1,3).value = 2
g.cell_at(1,5).value = 4

g.cell_at(2,2).value = 6
g.cell_at(2,7).value = 3

g.cell_at(3,3).value = 5
g.cell_at(3,8).value = 6

g.cell_at(4,0).value = 9
g.cell_at(4,2).value = 8
g.cell_at(4,5).value = 2
g.cell_at(4,7).value = 4

g.cell_at(5,1).value = 5
g.cell_at(5,4).value = 3
g.cell_at(5,6).value = 9

g.cell_at(6,2).value = 2
g.cell_at(6,4).value = 8
g.cell_at(6,7).value = 6

g.cell_at(7,1).value = 6
g.cell_at(7,3).value = 9
g.cell_at(7,6).value = 7
g.cell_at(7,8).value = 1

g.cell_at(8,0).value = 4
g.cell_at(8,5).value = 3

=begin
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
=end

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

