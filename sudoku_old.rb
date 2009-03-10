

class Cell

	attr_accessor :value
	attr_reader :possibles

	def initialize
		@value = nil
		@possibles = []
	end

	def add_possible(value)
		@possibles << value if !@possibles.include?(value)
	end

	def remove_possible(value)
		@possibles.delete(value)
	end

	def clear_possibles
		@possibles = []
	end

end

class Sudoku

	attr_reader :grid

	def initialize(grid)
		@grid = []
		9.times { |i|
			@grid[i] = []
			9.times { |j|
				@grid[i][j] = Cell.new
			}
		}

		9.times { |i|
			9.times { |j|
				if(!grid[i][j].nil?)
					@grid[i][j].value = grid[i][j]
				end
			}
		}
	end

	def print
		9.times { |i|
			9.times { |j|
				printf("%d ", @grid[i][j].value) if !@grid[i][j].value.nil?
				printf("_ ") if @grid[i][j].value.nil?
			}
			printf "\n"
		}
	end
end

class Solver
	def initialize(soduku)
		@soduku = soduku
		@grid = soduku.grid
	end

	def initialize_candidates
		# For each box without a value,
		# build up a list of candidates
		9.times { |i|
			9.times { |j|
				(1..9).each {|val|
					@grid[i][j].add_possible(val) if check_value(val, i, j)
				} if @grid[i][j].value.nil?
			}
		}
	end

	def solve
		cond = true
		while cond
			initialize_candidates
			locked_candidates_1
			cond = singles
		end
		@soduku.print
	end

	def each_in_row(i)
		@grid[i].each { |x|
			yield x.value if !x.value.nil?
		}
	end

	def each_in_col(j)
		9.times { |i|
			x = @grid[i][j]
			yield x.value if !x.value.nil?
		}
	end

	def each_in_box(i, j)
		box = [(0..2), (3..5), (6..8)]
		box.select { |x| x === i }[0].each { |i|
			box.select { |x| x === j }[0].each { |j|
				yield @grid[i][j].value
			}
		}
	end

	def each_box_range
		box = [(0..2), (3..5), (6..8)]
		box.each { |i|
			box.each { |j|
				yield i, j # yield the ranges for the box
			}
		}
	end

	def check_value(val, i, j)
		each_in_row(i) { |x|
			return false if x == val
		}
		each_in_col(j) { |x|
			return false if x == val
		}
		each_in_box(i,j) { |x|
			return false if x == val
		}
		return true
	end

=begin
Singles:
Any cells which have one candidate can safley be assigned a
value.
=end
	def singles
		found_something = false
		@grid.each { |row|
			row.each { |cell|
				if cell.possibles.length == 1
					found_something = true
					cell.value = cell.possibles[0] 
					cell.clear_possibles
				end
			}
		}
		return found_something
	end

=begin
Locked Candidates (1)
look for locked candidates and remove the numbers 
from the list of possibles.
=end
	def locked_candidates_1

		# Look for locked candidates
		# these rely on values in other box's only appearing in
		# 1 column or row in a box
		each_box_range { |i_range, j_range|
			(1..9).each { |val|
				# the columns and rows these values appear in
				# if these == 1 then we have to investigate further
				rows = []
				columns = []
				i_range.each{ |i|
					j_range.each {|j|
						if @grid[i][j].possibles.include?(val)
							rows << i if !rows.include?(i)
							columns << j if !columns.include?(i)
						end
					}
				}

				if rows.length == 1
					# with the exception of cells in
					# this j_range, remove all val's
					# from the possibles of anything else
					# in this row
					i = rows[0]
					@grid[i].each_index { |j|
						if !(j_range === j)
							p "removed locked candidate 1 ("+i.to_s+", "+j.to_s+" = "+val.to_s+")"
							@grid[i][j].remove_possible(val)
						end
					}
				end
				if columns.length == 1
					# same as before but for cols
					j = columns[0]
					9.times { |i|
						if !(i_range === i)
							p "removed locked candidate 1 ("+i.to_s+", "+j.to_s+" = "+val.to_s+")"
							@grid[i][j].remove_possible(val)
						end
					}
				end
			}
		}
	end

end

raw = [
		[nil, nil, nil, nil, nil, nil, nil,nil, nil],
		[nil, nil, 7, 8, 3, nil, 9, nil, nil],
		[nil, nil, 5, nil, nil, 2, 6, 4, nil],
		[nil, nil, 2, 6, nil, nil, nil, 7, nil],
		[nil, 4, nil, nil, nil, nil, nil, 8, nil],
		[nil, 6, nil, nil, nil, 3, 2, nil, nil],
		[nil, 2, 8, 4, nil, nil, 5, nil, nil],
		[nil, nil, nil, nil, 9, 6, 1, nil, nil],
		[nil, nil, nil, nil, nil, nil, nil,nil, nil]
]

s = Solver.new(Sudoku.new(raw))
s.solve
