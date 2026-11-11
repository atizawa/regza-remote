import EPGStationAPI

protocol EPGStationAPIRequest: APIRequest where Client == EPGStationAPI.Client {}
