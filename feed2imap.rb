#!/usr/bin/env ruby
# ruby 2.0

require 'rss'
require 'open-uri'
require 'net/imap'
require 'yaml'
require 'digest'

DIR = File.join(Dir.home, '/.config/feed2imap.rb')

cfg = File.join(Dir.home, '/.config')
Dir.mkdir(cfg) unless Dir.exists?(cfg)
Dir.mkdir(DIR) unless Dir.exists?(DIR)

IMAP_FILE  = File.join(DIR, 'imap.yml')  # login and pass to imap
FEEDS_FILE = File.join(DIR, 'feeds.yml') # list of feed, generated by add command
READ_FILE  = File.join(DIR, 'read.dat')  # old items

File.new(IMAP_FILE,  'w').close unless File.exists?(IMAP_FILE)
File.new(FEEDS_FILE, 'w').close unless File.exists?(FEEDS_FILE)
File.new(READ_FILE,  'w').close unless File.exists?(READ_FILE)

action = ARGV.first

def load_yaml(file_path)
  file = File.open(file_path, 'r')

  data = file.read
  file.close

  YAML.load(data) || {}
end

def load_feeds
  load_yaml(FEEDS_FILE)
end

def add
  raise 'You should provide feed name and feed url' unless ARGV.count == 3

  yaml = load_feeds

  feed_name = ARGV[1]
  feed_url  = ARGV[2]

  yaml[feed_name] ||= []
  yaml[feed_name] << feed_url
  yaml[feed_name].uniq!

  file = File.open(FEEDS_FILE, 'w')
  file.write(yaml.to_yaml)
  file.close
end

def load_imap_file
  load_yaml(IMAP_FILE)
end

def get_username
  load_imap_file['username']
end

def get_password
  load_imap_file['password']
end

def get_to
  load_imap_file['to']
end

def get_from
  load_imap_file['from']
end

def get_imap_host
  load_imap_file['host']
end

def get_imap_port
  load_imap_file['port']
end

def fetch_title(item)
  case item
  when RSS::Atom::Feed::Entry  then item.title.content
  when RSS::Rss::Channel::Item then item.title
  end
end

def fetch_author(item)
  case item
  when RSS::Atom::Feed::Entry  then if item.author
                                      item.author.name.content
                                    else
                                      ''
                                    end
  when RSS::Rss::Channel::Item then item.author.to_s
  end
end

def fetch_content(item)
  case item
  when RSS::Atom::Feed::Entry  then (item.content || item.summary).content
  when RSS::Rss::Channel::Item then item.description
  end
end

def fetch_link(item)
  case item
  when RSS::Atom::Feed::Entry  then item.link.href
  when RSS::Rss::Channel::Item then item.link
  end
end

def item_digest(item)
  title   = fetch_title(item)
  author  = fetch_author(item)
  link    = fetch_link(item)

  str = title + author + link

  Digest::MD5.new.hexdigest(str)
end

def new_item?(item)
  `grep '#{item_digest(item)}' #{READ_FILE}`.empty?
end

def mark_as_read(item)
  file = File.open(READ_FILE, 'a')
  file.puts(item_digest(item))
  file.close
end

def format_item(item)
  title   = fetch_title(item)
  author  = fetch_author(item)
  content = fetch_content(item)
  link    = fetch_link(item)

  <<-EOS
MIME-Version: 1.0
From: #{get_from}
To: #{get_to}
Subject: #{title}
Date: #{Time.now.strftime("%a, %d %b %Y %H:%M:%S %z")}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: 8bit

<table>
  <tr><td>
    <a href="#{link}">#{title}</a>
  </td></tr>

  <tr><td>
    <p>#{author}</p>
  </td></tr>

  <tr><td>
    #{content}
  </td></tr>
</table>
  EOS
end

def pull_feed(feed_name, feed_url, imap)
  if not imap.list('RSS/', feed_name)
    imap.create("RSS/#{feed_name}")
  end

  data = open(feed_url) do |f|
    f.read
  end

  rss = RSS::Parser.parse(data, false)
  rss.items.each do |item|
    imap.noop
    html = format_item(item)

    if new_item?(item)
      puts "Saving item \"#{fetch_title(item)}\" from #{feed_url} in to the folder named #{feed_name}"
      imap.append("RSS/#{feed_name}", html, [], Time.now)
      mark_as_read(item)
    end
  end
end

def pull
  imap = Net::IMAP.new(get_imap_host, port: get_imap_port, ssl: true)
  imap.login(get_username, get_password)

  if not imap.list('', 'RSS')
    imap.create("RSS")
  end

  load_feeds.each do |feed_name, urls|
    puts "Pulling feeds for #{feed_name} from #{urls.count} sources."
    urls.each do |url|
      imap.noop
      puts "Fetching data from #{url}"
      pull_feed(feed_name, url, imap)
    end
  end

  imap.logout
  imap.disconnect
end

case action
when 'add'
  add
when 'pull'
  pull
else
  raise 'Unknown action'
end
