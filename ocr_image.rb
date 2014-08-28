require 'opencv'
require 'pry'

include OpenCV

if ARGV.size == 0
  puts "Usage: ruby #{__FILE__} ImageToLoadAndDisplay"
  exit
end

image = nil
begin
  image = CvMat.load(ARGV[0], CV_LOAD_IMAGE_COLOR) # Read the file.
rescue
  puts 'Could not open or find the image.'
  exit
end

SUDOKU_SIZE = 9

single_channel = image.split[0]
dst = single_channel.clone.canny(1, 1)
contour = dst.find_contours(:mode => OpenCV::CV_RETR_TREE, :method => OpenCV::CV_CHAIN_APPROX_SIMPLE)
main_box = nil
while contour
  unless contour.hole?
    box = contour.bounding_rect
    main_box = box
  end
  contour = contour.h_next
end 

## Loop over this to map this onto 9 * 9 matrix
top_left_point = OpenCV::CvPoint.new
bottom_right_point = OpenCV::CvPoint.new
box_width = (main_box.width / SUDOKU_SIZE).round
box_height = (main_box.height / SUDOKU_SIZE).round

top_left_point.x = main_box.top_left.x
top_left_point.y = main_box.top_left.y
bottom_right_point.x = box_width + main_box.top_left.x
bottom_right_point.y = box_height + main_box.top_left.y
@existing_board = Array.new(SUDOKU_SIZE) { Array.new(SUDOKU_SIZE) { nil } }
1.upto(SUDOKU_SIZE) do |y|
  1.upto(SUDOKU_SIZE) do |i|
    this_box = image.sub_rect(top_left_point.x + 7, top_left_point.y + 7, box_width - 10, box_height - 10)
    this_box.save_image("temp_single_cell.jpg")
    @existing_board[y-1][i-1] = `gocr -i temp_single_cell.jpg -m 1 -u 0 -C 1234567890`.chomp.to_i
    top_left_point.x = (box_width * i) + main_box.top_left.y
    bottom_right_point.x = (box_width * i) + box_width + main_box.top_left.x
  end
  top_left_point.x = main_box.top_left.x
  top_left_point.y = main_box.top_left.y + (box_height * y)
  bottom_right_point.x = box_width + main_box.top_left.x
  bottom_right_point.y = (box_height * y) + main_box.top_left.y + box_width
end

puts @existing_board.inspect