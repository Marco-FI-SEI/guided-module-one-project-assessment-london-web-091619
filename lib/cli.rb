require "pry"
require "tty-prompt"
require "encrypted_strings"

class CLI
  @@prompt = TTY::Prompt.new

  #--------------------------------------------------------------------------------------------------------#
  # RUN METHOD #
  #--------------------------------------------------------------------------------------------------------#

  def run
    choice = @@prompt.select(" Sign up or Log in to enjoy our fantastic Gelato!", " Log In", " Sign Up")
    choice == " Sign Up" ? @current_user = sign_up_user : @current_user = log_in_user

    if @current_user
      main_menu
    else
      puts " Sorry, your username/password did not match. Please try again."
      run
    end
  end

  #--------------------------------------------------------------------------------------------------------#
  # USER ACCOUNT #
  #--------------------------------------------------------------------------------------------------------#

  def sign_up_user
    full_name = @@prompt.ask(" Please enter your Full Name: ")
    email_add = @@prompt.ask(" Please enter your Email Address (This will be your Username): ")
    postal_add = @@prompt.ask(" Please enter your Postal Address: ")
    password1 = @@prompt.mask(" Please enter your Password: ")
    password2 = @@prompt.mask(" For security purposes, Please Re-enter your Password: ")
    if password1 == password2
      User.create(name: full_name, password: password1.encrypt, address: postal_add, email: email_add)
    end
  end

  def log_in_user
    username = @@prompt.ask(" Please enter your username: ")
    password = @@prompt.mask(" Please enter your password: ")
    User.find_by(email: username, password: password.encrypt)
  end

  def good_bye
    system("clear")
    puts " Thank you for visiting K&M Gelato! Come back soon!\n"
  end

  #--------------------------------------------------------------------------------------------------------#
  # MAIN MENU #
  #--------------------------------------------------------------------------------------------------------#

  def main_menu
    sleep(1)
    system("clear")
    menu_choice = @@prompt.select(" Hello there! What can we do for you today?\n",
                                  " Create New Order", " Edit Order", " Cancel Order", " My Orders", " About/Promo", " Exit")

    case menu_choice
    when " Create New Order"
      create_order
      main_menu
    when " Edit Order"
      edit_order
      where_to_next
    when " Cancel Order"
      cancel_order
      where_to_next
    when " My Orders"
      display_orders(my_orders)
      where_to_next
    when " About/Promo"
      about_us
      where_to_next
    when " Exit"
      good_bye
    else
      puts " You seem to have broken our application, thank you!"
    end
  end

  #--------------------------------------------------------------------------------------------------------#
  # ORDERS #
  #--------------------------------------------------------------------------------------------------------#

  def create_order
    servings = @@prompt.ask(" How many servings would you like? ")
    if servings_valid?(servings.to_i)
      total = servings.to_f * 5.0
      Order.create(user_id: @current_user.id, gelato_id: get_gelato(1).id, order_time: order_timestamp,
                   status: "pending", total: total, servings: servings)
      remove_stock(servings, get_gelato(1).id)
      stock_control(servings, get_gelato(1).id)

      puts " Thanks, we're on it!"
    else
      create_order
    end
  end

  def string_order_to_object(string)
    id = string.partition(".").first
    order = Order.find(id)
  end

  def go_to_menu(string)
    main_menu if string == " Main menu"
  end

  def edit_order
    if pending_orders.empty?
      puts "\n You do not have any orders to choose from...\n"
    else
      order_to_edit = @@prompt.select("\n Which order would you like to edit?", orders_selection, " Main menu")
      go_to_menu(order_to_edit)
      order_object = string_order_to_object(order_to_edit)
      servings = @@prompt.ask(" How many servings would you like instead?")
      if servings_valid?(servings.to_i)
        add_stock(order_object.servings, order_object.gelato_id)
        remove_stock(servings, order_object.gelato_id)
        update_total(order_object, servings)
        stock_control(servings, get_gelato(1).id)
        order_object.servings = servings
        order_object.save
        puts " Your order has been edited"
      else
        edit_order
      end
    end
  end

  def cancel_order
    if pending_orders.empty?
      puts "\n You do not have any orders to choose from...\n"
    else
      order_to_cancel = @@prompt.select(" Which order would you like to cancel?", orders_selection, " Main menu")
      go_to_menu(order_to_cancel)
      order_object = string_order_to_object(order_to_cancel)
      order_object.save
      add_stock(order_object.servings, get_gelato(1).id)
      puts " Your order has been cancelled"
      delete_order(order_object)
    end
  end

  def delete_order(order)
    Order.delete(order.id)
  end

  def display_orders(orders)
    puts "\n Your orders:\n"
    orders.each_with_index do |order, index|
      puts "#{index + 1}: #{order.servings} servings of #{get_gelato(order.gelato_id).flavour} at #{order.order_time}. Order total was: £#{order.total}"
    end
    puts "\n"
  end

  def orders_selection
    pending_orders.map { |order|
      "     #{order.id}.
        Date and Time: #{order.order_time.to_s}
        Flavour: #{get_gelato(order.gelato_id).flavour}
        Servings: #{order.servings.to_s}"
    }
  end

  def my_orders
    Order.all.select { |order| order.user_id == @current_user.id }
  end

  def pending_orders
    my_orders.select { |order| order.status == "pending" }
  end

  def order_timestamp
    Time.now.strftime("%d/%m/%Y, %H:%M")
  end

  def update_total(order_to_edit, new_servings)
    order_to_edit.total = new_servings.to_f * 5
  end

  #--------------------------------------------------------------------------------------------------------#
  # STOCK #
  #--------------------------------------------------------------------------------------------------------#

  def remove_stock(servings, id)
    current_gelato = get_gelato(id)
    current_gelato.stock -= servings.to_f
    current_gelato.save
  end

  def add_stock(order_stock, id)
    current_gelato = get_gelato(id)
    current_gelato.stock += order_stock.to_f
    current_gelato.save
  end

  def stock_control(servings, id)
    current_stock = get_gelato(id).stock
    add_stock(100 - current_stock, id) if current_stock <= servings.to_i || current_stock <= 10
  end

  def get_gelato(id)
    Gelato.find(id)
  end

  #--------------------------------------------------------------------------------------------------------#
  # VALIDATION #
  #--------------------------------------------------------------------------------------------------------#
  # validates user input and calls create or edit order depending on flag passed in

  def servings_valid?(servings)
    if servings > 50
      system("clear")
      puts " Due to high demand, we can only complete orders of up to 50 servings at one time. Sorry for the inconvenience.\n"
      return false
    elsif servings <= 0
      system("clear")
      puts " Please enter a valid number of servings.\n"
      return false
    end
    true
  end

  #--------------------------------------------------------------------------------------------------------#
  # PROGRAM FLOW #
  #--------------------------------------------------------------------------------------------------------#

  # call create or edit method based on flag
  def enact_flag(flag)
    flag == "from create" ? create_order : edit_order
  end

  # called after user performs action to get next step
  def where_to_next
    response = @@prompt.select(" Is there anything else we can do for you today?\n", "Yeah, I'm not done yet!", "No, thanks!")
    response == "Yeah, I'm not done yet!" ? main_menu : good_bye
  end

  #--------------------------------------------------------------------------------------------------------#
  # About #
  #--------------------------------------------------------------------------------------------------------#

  def about_us
    puts "\n\n Here at K&M, we pride ourselves on our ability to provide you with the highest \n quality Gelato at the very best price. Our unique boutique blend of rich and chewy \n chocolate brownies combined with decadent caramel swirls will leave you begging to \n know the recipe. But wait, there's more! Sign up and order with us today or spend £20\n or more in store to recieve a 10% discount off your total order cost. \n\n So what are you waiting for? Order now!\n\n"
  end
end

# ADMIN USER
# grey out/dont display options that arent yet available
# discont service
# many flavours
# pending time period (2 mins)
# display my orders in a prettier way
