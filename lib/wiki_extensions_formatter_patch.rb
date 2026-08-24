# Wiki Extensions plugin for Redmine
# Copyright (C) 2011-2017  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# R7 (refs #108530): two changes here.
#  1. `require_dependency` no longer force-loads core lib/ files -> plain `require`.
#  2. Redmine 7 SPLIT the Textile formatter: `Formatter` now delegates to a new
#     `Filter < RedCloth3` class, and the inline/block rule list `RULES` moved from
#     `Formatter` to `Filter` (Formatter#to_html just runs the filter, then Loofah
#     scrubbers). So the emoticon rule must be registered on, and prepended to,
#     `Textile::Filter` — targeting `Formatter` raises NameError on RULES.
require "redmine/wiki_formatting/textile/formatter"

module WikiExtensionsFormatterPatch
  Redmine::WikiFormatting::Textile::Filter::RULES << :inline_smiles

  private

  def inline_smiles(text)
    emoticon_path = WikiExtentionEmoticonPath.new

    @emoticons = WikiExtensionsEmoticons::Emoticons.new
    @emoticons.emoticons.each { |emoticon|
      src = emoticon_path.get_emoticon_path(emoticon["image"])
      text.gsub!(Regexp.new("#{Regexp.escape(emoticon["emoticon"])}(\\s|<br/>|</p>)"),
                 "<img src=\"#{src}\" alt=\"#{emoticon["emoticon"]}\">\\1")
    }
  end

  class WikiExtentionEmoticonPath
    include Rails.application.routes.url_helpers

    def get_emoticon_path(emoticon)
      wiki_extensions_emoticon_path(emoticon)
    end
  end
end

Redmine::WikiFormatting::Textile::Filter.prepend(WikiExtensionsFormatterPatch)
