import MirakurunAPI

protocol MirakurunAPIRequest: APIRequest where Client == MirakurunAPI.Client {}
