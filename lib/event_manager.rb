require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip
  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_numbers(phone_number)
  phone_number = phone_number.to_s.gsub(/[^\d]/, '')
  length = phone_number.length

  if length == 10
    phone_number
  elsif length == 11 && phone_number.start_with?('1')
    phone_number[1..-1]
  else
    '0000000000'
  end
end

def get_hours(regdate)
  DateTime.strptime(regdate, '%m/%d/%y %H:%M').strftime('%k').to_i
rescue ArgumentError => e 
  puts "Invalid registration date format: #{e.message}"
  nil
end

def get_days(regdate)
  DateTime.strptime(regdate, '%m/%d/%y %H:%M').wday
rescue ArgumentError => e 
  puts "Invalid registration date format: #{e.message}"
  nil
end

def calculate_peak_hours(hours)
  freq = hours.compact.tally 
  freq = freq.sort_by { |_key, value| -value }.to_h
  peak_hours = freq.keys.first(3) 
  puts "The peak registration hours were #{peak_hours[0]} o'clock, #{peak_hours[1]} o'clock and #{peak_hours[2]} o'clock"
end

def weekday(wday)
  days_of_week = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  days_of_week[wday]
end

def calculate_peak_days(days)
  freq = days.compact.tally 
  freq = freq.sort_by { |_key, value| -value }.to_h
  peak_days = freq.keys.first(3) 
  
  peak_days = peak_days.map { |wday| weekday(wday) }
  puts "The peak registration days were on #{peak_days[0]}, #{peak_days[1]} and #{peak_days[2]}"
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hours = []
days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone_number = clean_phone_numbers(row[:homephone])
  regdate = row[:regdate]
  hours << get_hours(regdate)
  days << get_days(regdate)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

calculate_peak_hours(hours)
calculate_peak_days(days)
