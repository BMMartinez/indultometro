require "rubygems"
require "bundler/setup"

require 'sinatra/base'
require 'json'
require './app/model'

class IndultometroApp < Sinatra::Base

  # Enable serving of static files
  set :static, true
  set :public_folder, 'web/_site'

  get '/' do
    redirect '/index.html'
  end

  get '/api/summary' do
    set_cache_headers

    count = repository(:default).adapter.select('
      SELECT 
        pardon_year, 
        count(pardon_year) 
      FROM 
        pardons 
      GROUP BY pardon_year 
      ORDER BY pardon_year ASC')
    result = []
    count.each do |item| 
      result.push({ :year => item.pardon_year.to_i, :count => item.count })
    end

    send_response(response, result, params)
  end
  
  get '/api/cat_summary' do
    set_cache_headers
    count = repository(:default).adapter.select('
      SELECT 
        pcc.crime_cat, 
        cc.description, 
        count(*) as count 
      FROM 
        pardon_crime_categories as pcc, 
        crime_categories as cc
      WHERE 
        pcc.crime_cat = cc.crime_cat AND
        cc.crime_sub_cat IS NULL
      GROUP BY 
        pcc.crime_cat,
        cc.description 
      ORDER BY 
        pcc.crime_cat')
    result = []
    count.each do |item| 
      result.push({ :crime_cat => item.crime_cat.to_i, :description => item.description, :count => item.count })
    end

    send_response(response, result, params)
  end
  
  # TODO: Rename this method
  get '/api/cat_pardons' do
    set_cache_headers
    result = []

    # Get the category, return nothing if none given
    cat = params['crime_cat']
    if cat
      # TODO: Use DataMapper instead?
      result = repository(:default).adapter.select("
        SELECT * 
        FROM 
          pardons as p, 
          pardon_crime_categories as pcc
        WHERE 
          p.id = pcc.boe AND
          pcc.crime_cat = ?
        ORDER BY 
          p.pardon_year", cat)
      result.collect! {|pardon| pardon_summary(pardon) }
    end

    send_response(response, result, params)
    
  end

  get '/api/pardons' do
    set_cache_headers

    year = params['year'] || '2013'   # FIXME hardcoded year
    pardons = Pardon.all(:pardon_year => year)
    # Keep only a summary of the data. I tried using DataMapper's field option, 
    # but didn't work, it kept populating the JSON with all the fields (!?)
    result = pardons.map {|pardon| pardon_summary(pardon) }

    send_response(response, result, params)
  end

  get '/api/pardons/:id' do
    set_cache_headers
    pardon = Pardon.get(params[:id])
    send_response(response, pardon, params)
  end

  get '/api/search' do
    set_cache_headers
    result = []

    # Get the query string, return nothing if none given
    query = params['q']
    if query
      result = repository(:default).adapter.select("
        SELECT
          id, pardon_date, pardon_type, crime, pardon_year
        FROM 
          pardons 
        WHERE 
          to_tsvector(crime) @@ plainto_tsquery(?)", query)
      result.collect! {|pardon| pardon_summary(pardon) }
    end

    send_response(response, result, params)
  end

  def pardon_summary(pardon)
    summary = {}
    [:id, :pardon_date, :pardon_type, :crime, :pardon_year].each do |field|
      summary[field] = pardon[field]
    end
    summary
  end

  def set_cache_headers
    # TODO: Improve caching with ETags http://www.sinatrarb.com/intro#Cache%20Control
    cache_control :public, :must_revalidate, :max_age => 3600
  end

  def send_response(response, result, params)
    if params['callback']
      response.headers['Content-Type'] = 'text/javascript; charset=utf8'
      response.headers['Access-Control-Allow-Origin'] = '*'
      # FIXME response.headers['Access-Control-Max-Age'] = '3600'
      response.headers['Access-Control-Allow-Methods'] = 'GET'

      "#{params['callback']}(#{result.to_json})"
    else
      content_type :json
      result.to_json
    end
  end
end
