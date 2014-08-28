require 'rspec'

require_relative '../solving_sudoku'

describe :SolvingSudoku do

  it "should be possible to create an instance" do
    SolvingSudoku.new.should_not be_nil
  end

  it "should be possible to only create 9 based boards" do
    SolvingSudoku.new(9).should_not be_nil
    lambda { SolvingSudoku.new(17) }.should raise_error
  end

end