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
rescue ArgumentError
    puts "Invalid argument"
end

def get_days(regdate)
  DateTime.strptime(regdate, '%m/%d/%y %H:%M').wday
rescue ArgumentError
  puts "Invalid argument"
end

# def calculate_peak_hour(hours)
# end

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
