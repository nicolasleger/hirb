require File.join(File.dirname(__FILE__), 'test_helper')

class Hirb::MenuTest < Test::Unit::TestCase
  before(:all) { Hirb::View.instance_variable_set("@config", :width=>Hirb::View::DEFAULT_WIDTH) }

  def menu(*args, &block)
    # testing via menu's main use case (through console) instead of Hirb::Menu.render
    @console ||= Object.new.extend(Hirb::Console)
    @console.menu(*args, &block)
  end

  def basic_menu(*args, &block)
    menu_input('1')
    capture_stdout { menu(*args, &block).should == [1] }
  end

  def menu_input(input='')
    $stdin.expects(:gets).returns(input)
  end

  context "menu" do
    test "by default renders table menu" do
      expected_menu = <<-MENU.unindent
      +--------+-------+
      | number | value |
      +--------+-------+
      | 1      | 1     |
      | 2      | 2     |
      | 3      | 3     |
      +--------+-------+
      3 rows in set
      MENU
      basic_menu([1,2,3]).include?(expected_menu).should == true
    end

    test "with block renders" do
      menu_input "1,2"
      expected_result = [1,2]
      capture_stdout { 
        menu([1,2,3]) {|e| e.should == expected_result }.should == expected_result
      }
    end

    test "with block and no chosen doesn't call block" do
      menu_input ""
      block = lambda {|e| @called = true }
      capture_stdout {
        menu([1,2,3], &block).should == []
      }
      assert !@called
    end

    test "with valid helper_class option renders" do
      Hirb::Helpers::Table.expects(:render)
      basic_menu [1,2,3], :helper_class=>"Hirb::Helpers::Table"
    end

    test "with invalid helper_class option renders default menu" do
      expected_menu = <<-MENU.unindent
      1: 1
      2: 2
      3: 3
      MENU
      basic_menu([1,2,3], :helper_class=>"SomeHelper").include?(expected_menu).should == true
    end

    test "with false helper_class option renders default menu" do
      expected_menu = <<-MENU.unindent
      1: 1
      2: 2
      3: 3
      MENU
      basic_menu([1,2,3], :helper_class=>false).include?(expected_menu).should == true
    end

    test "prints prompt option" do
      prompt = "Input or else ..."
      basic_menu([1,2,3], :prompt=>prompt).include?(prompt).should == true
    end

    test "converts non-array inputs to array" do
      Hirb::Helpers::AutoTable.expects(:render).with([1], anything)
      basic_menu 1
    end

    test "with false ask option returns one choice without asking" do
      $stdin.expects(:gets).never
      menu([1], :ask=>false).should == [1]
    end

    test "with no items to choose from always return without asking" do
      $stdin.expects(:gets).never
      menu([], :ask=>false).should == []
      menu([], :ask=>true).should == []
    end

    test "with directions option turns off directions" do
      menu_input('blah')
      capture_stdout { menu([1], :directions=>false) }.should_not =~ /range.*all/
    end
  end

  def two_d_menu(options={})
    if options[:invokes] || options[:invoke]
      cmd = options[:command] || 'p'
      (options[:invokes] || [options[:invoke]]).each {|e|
        Hirb::Menu.any_instance.expects(:invoke).with(cmd, e)
      }
    end

    capture_stdout {
      return menu([{:a=>1, :bro=>2}, {:a=>3, :bro=>4}], {:two_d=>true}.merge(options))
    }
  end

  context "2d menu" do
    test "with default field from last_table renders" do
      menu_input "1"
      two_d_menu.should == [1]
    end

    test "with default field from fields option renders" do
      menu_input "1"
      two_d_menu(:fields=>[:bro, :a]).should == [2]
    end

    test "with default field option renders" do
      menu_input "1"
      two_d_menu(:default_field=>:bro).should == [2]
    end

    test "with non-table helper class renders" do
      menu_input "1"
      two_d_menu(:helper_class=>false, :fields=>[:a,:bro]).should == [1]
    end

    test "with no default field prints error" do
      menu_input "1"
      capture_stderr { two_d_menu(:fields=>[]) }.should =~ /No default.*found/
    end

    test "with invalid field prints error" do
      menu_input "1:z"
      capture_stderr { two_d_menu }.should =~ /Invalid.*'z'/
    end

    test "with choice from abbreviated field" do
      menu_input "2:b"
      two_d_menu.should == [4]
    end

    test "with choices from multiple fields renders" do
      menu_input "1 2:bro"
      two_d_menu.should == [1,4]
    end
  end

  context "action menu" do
    test "invokes" do
      menu_input "p 1 2:bro"
      two_d_menu(:action=>true, :invoke=>[[1,4]])
    end

    test "with 1d invokes" do
      menu_input "p 1"
      two_d_menu(:action=>true, :two_d=>nil, :invoke=>[[{:a=>1, :bro=>2}]])
    end

    test "with non-choice arguments invokes" do
      menu_input "p arg1 1"
      two_d_menu :action=>true, :invoke=>['arg1', [1]]
    end

    test "with nothing chosen prints error" do
      menu_input "cmd"
      capture_stderr { two_d_menu(:action=>true) }.should =~ /No rows chosen/
    end

    test "with no command given prints error" do
      menu_input "1"
      capture_stderr { two_d_menu(:action=>true) }.should =~ /No command given/
    end

    test "with multi_action option invokes" do
      menu_input "p 1 2:bro"
      two_d_menu(:action=>true, :multi_action=>true, :invokes=>[[1], [4]])
    end

    test "with command option invokes" do
      menu_input "1"
      two_d_menu(:action=>true, :command=>'p', :invoke=>[[1]])
    end

    test "with command option and empty input doesn't invoke action and exists silently" do
      Hirb::Menu.any_instance.expects(:invoke).never
      menu_input ""
      two_d_menu(:action=>true, :command=>'p').should == nil
    end

    test "with action_object option invokes" do
      obj = mock(:blah=>true)
      menu_input "blah 1"
      two_d_menu(:action=>true, :action_object=>obj)
    end
  end
end