json.extract! ride_post, :id, :ride_schedule_id, :departure_date, :remaining_seats, :created_at, :updated_at
json.url ride_post_url(ride_post, format: :json)
