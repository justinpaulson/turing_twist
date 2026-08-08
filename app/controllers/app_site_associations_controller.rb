class AppSiteAssociationsController < ActionController::Base
  APP_ID = "H8TX3AP66F.com.justinpaulson.TuringTwist"

  def show
    expires_in 1.hour, public: true
    render json: {
      applinks: {
        details: [
          {
            appIDs: [ APP_ID ],
            components: [
              {
                "/": "/invite/games/*",
                comment: "Opens a shared game invitation in Turing Twist"
              }
            ]
          }
        ]
      }
    }
  end
end
