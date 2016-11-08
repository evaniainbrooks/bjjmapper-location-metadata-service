module Math
  def self.radians(degs)
    return degs * Math::PI / 180
  end

  def self.circle_distance(lat0, lng0, lat1, lng1)
    r = 3963.0
    return r * Math.acos(Math.sin(radians(lat0)) * Math.sin(radians(lat1)) + Math.cos(radians(lat0)) * Math.cos(radians(lat1)) * Math.cos(radians(lng1) - radians(lng0)))
  end
end
