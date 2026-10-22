module DriverEligibility
  extend ActiveSupport::Concern

  included do
    scope :with_eligible_drivers, -> {
      memberships = CommunityMembership.active_verified
        .where(CommunityMembership.arel_table[:user_id].eq(arel_table[:user_id]))
        .where(CommunityMembership.arel_table[:community_id].eq(arel_table[:community_id]))

      where(user_id: User.eligible_for_offering.select(:id))
        .where(arel_table[:ladies_only].eq(false).or(arel_table[:user_id].in(User.female.select(:id).arel)))
        .where(arel_table[:visibility].not_eq(visibilities.fetch("hub_only")).or(memberships.arel.exists))
    }
  end

  def driver_eligible?
    return false unless user&.eligible_for_offering?
    return false if hub_only? && !user.verified_member_of?(community_id)
    return false if ladies_only? && !user.female?

    true
  end
end
