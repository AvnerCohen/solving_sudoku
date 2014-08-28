require 'pry'
require 'opencv'

if ARGV.size == 0
  puts "Usage: ruby #{__FILE__} suduko_image.whatever"
  exit
end

IMAGE_NAME=ARGV[0]

class SolvingSudoku
  include OpenCV

  Point = Struct.new(:x, :y)
  attr_accessor :board, :size, :sqrt, :iterations, :max, :repeating_error
  attr_accessor :pre_populated_board
  attr_accessor :step_list, :current_x, :current_y

  def initialize
    @iterations = 0
    @max = 0
    @step_list = []
    @repeating_error = 0
    @size = 9
    @sqrt = Math.sqrt(size)
    @image = nil
    @empty_boxes = Array.new(size) { Array.new(size) { nil } }
    @pre_populated_board = run_ocr_for_prepopulated_board(IMAGE_NAME)
    @board = @pre_populated_board.dup
  end

  def solve!
    numbers = (1..@size).to_a
    @current_x = 0
    @current_y = 0
    while !board_completed? do
      num = 0
      num = extract_random(numbers)
      results = populate_single_digit(num)
      if results == :AlreadyPresent && @repeating_error > (size * 3)
        backtrack
      elsif results == :AlreadyPresent
        @repeating_error = @repeating_error + 1
      else
        @repeating_error = 0
      end
    end
  end

  def populate_single_digit(digit)
    point = nil
    @iterations = @iterations + 1
    x = @current_x
    y = @current_y
    point = Point.new(x, y)
    if pre_populated_board[point.y][point.x] != 0
      next_cell
      return :AlredyPresent
    end
    return :AlreadyPresent if !board[point.y][point.x] == 0 && pre_populated_board[point.y][point.x] == 0
    if digit_invalid_at_point?(digit, x, y)
      return :AlreadyPresent
    else
      board[point.y][point.x] = digit
      @step_list << point
    end

    next_cell
  end

  def next_cell
    @current_x = @current_x + 1
    if @current_x >= size
      @current_x = 0
      @current_y = @current_y + 1
      if @current_y >= size && @current_x == 0
        @current_y = 0
      end
    end
  end

  def digit_invalid_at_point?(digit, x, y)
    row_contains_value?(y, digit) ||
    block_contains_value?(y, x, digit) ||
    column_contains_value?(x, digit)
  end

  def backtrack
    @max = [@max, @step_list.size].max
    last_step = @step_list.pop
    return if last_step.nil?
    @board[last_step.y][last_step.x] = 0
    @current_x = last_step.x
    @current_y = last_step.y
  end

  def block_contains_value?(row_index, column_index, value)
    start_row_index = row_index - (row_index % @sqrt)
    start_column_index = column_index - (column_index % @sqrt)
    end_row_index = start_row_index + @sqrt - 1
    end_column_index = start_column_index + @sqrt - 1
    board[start_row_index..end_row_index].each do |row|
      row[start_column_index..end_column_index].each do |cell_value|
        return true if cell_value == value
      end
    end
    false
  end

  def board_completed?
    @board.flatten.count(0) == 0
  end

  def row_contains_value?(y, digit)
    @board[y].compact.count(digit) > 0
  end

  def column_contains_value?(x, digit)
    column_values = []
    @board.each do |row|
      column_values << row[x]
    end
    column_values.compact.count(digit) > 0
  end

  def extract_random(num_range)
    num = (rand(num_range.length) + 1)
  end

  def run_ocr_for_prepopulated_board(image_name)
    @image = nil
    begin
      @image = CvMat.load(image_name, CV_LOAD_IMAGE_COLOR) # Read the file.
    rescue => e
      puts "Could not open or find the image. #{e.inspect}"
      exit
    end

    dst = @image.split[0].clone.canny(1, 1)
    contour = dst.find_contours(:mode => OpenCV::CV_RETR_TREE, :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
    main_box = nil
    while contour
      unless contour.hole?
        box = contour.bounding_rect
        main_box = box
      end
      contour = contour.h_next
    end

    top_left_point = OpenCV::CvPoint.new
    bottom_right_point = OpenCV::CvPoint.new
    box_width = (main_box.width / @size).round
    box_height = (main_box.height / @size).round

    top_left_point.x = main_box.top_left.x
    top_left_point.y = main_box.top_left.y
    bottom_right_point.x = box_width + main_box.top_left.x
    bottom_right_point.y = box_height + main_box.top_left.y
    board_populated = Array.new(@size) { Array.new(@size) { 0 } }
    1.upto(@size) do |y|
      1.upto(@size) do |i|
        this_box = @image.sub_rect(top_left_point.x + 7, top_left_point.y + 7, box_width - 10, box_height - 10)
        this_box.save_image("temp_single_cell.jpg")
        val = `gocr -i temp_single_cell.jpg -m 1 -u 0 -C 1234567890`.chomp.to_i
        board_populated[y-1][i-1] = val
        if val == 0
          @empty_boxes[y-1][i-1] = [top_left_point.x + 7, top_left_point.y + 7, box_width - 10, box_height - 10]
        end
        top_left_point.x = (box_width * i) + main_box.top_left.y
        bottom_right_point.x = (box_width * i) + box_width + main_box.top_left.x
      end
      top_left_point.x = main_box.top_left.x
      top_left_point.y = main_box.top_left.y + (box_height * y)
      bottom_right_point.x = box_width + main_box.top_left.x
      bottom_right_point.y = (box_height * y) + main_box.top_left.y + box_width
    end

    board_populated
  end

  def draw_missing
    font = CvFont.new(:plain, :vscale => 6.5, :shear => 1.0, :thickness => 2, :line_type => 5, :italic => true)
    1.upto(@size) do |y|
      1.upto(@size) do |i|
        cell = @empty_boxes[y-1][i-1]
        if cell
          point = CvPoint.new(cell[0] + 5, cell[1] + 50)
          @image.put_text!(@board[y-1][i-1].to_s, point, font, CvColor::Red)
        end
      end
    end

    window = GUI::Window.new("Resolved Suduko")
    window.show @image

    GUI::wait_key
  end

  ## Debug Utility method
  def to_s(board_to_print, clean = true)
    puts "\e[H\e[2J" if clean
    puts "Done! - Interations - #{@iterations}"
    (0..board_to_print.size-1).each do |i|
      STDOUT.print "#{'---' * size}\n" if i % sqrt == 0
      board_to_print[i].each_with_index do |val, index|
        delimiter = ""
        delimiter = " | " if (index + 1) % sqrt == 0
        printf("%2d#{delimiter}", val.to_i)
      end
      STDOUT.print "\n"
    end
    puts "---" * size
  end

end

solved_board = SolvingSudoku.new
solved_board.solve!
solved_board.draw_missing


##solved_board.to_s(solved_board.board)